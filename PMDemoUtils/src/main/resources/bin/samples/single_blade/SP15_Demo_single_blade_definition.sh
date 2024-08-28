#!/bin/bash

#
# This sample script contains the commands used for a LITP installation creating
# the definition part for the following configuration:
#
# Type: Single-Blade
# Config:	MS (Managing Server)
#			2 SC Nodes (Service Control Nodes)
#			2 PL Nodes (Pay Load Nodes)
#			1 NFS Node (SFS/NFS network filesystems)
#
# Hardware:	One physical server (Blade or Rackmount) and managed nodes are
#			installed as VMs in MS1.
#
# Campaigns: Jboss
#
# Target built: SP13
#
# If your LITP hardware configuration differs from this, you will need to
# modify script to suit your own requirements.
#
# Various settings used in this sample script are environment specific,
# these include IP addresses, MAC addresses, netid, TIPC addresses,
# serial numbers, usernames, passwords etc and may also need to be
# modified to suit your requirements.
#
# For more details, please visit the documentation site here:
# https://team.ammeon.com/confluence/display/LITPExt/Landscape+Installation
#


# 
# Helper function for debugging purpose. 
# ----------------------------------------
# Reduces the clutter on the script's output while saving everything in 
# landscape.log file in the user's current directory. Can safely be removed 
# if not needed.

STEP=0
LOGDIR="logs"
if [ ! -d "$LOGDIR" ]; then
    mkdir $LOGDIR
fi
LOGFILE="${LOGDIR}/landscape_definition.log"
if [ -f "${LOGFILE}" ]; then
    mod_date=$(date +%Y%m%d_%H%M%S -r "$LOGFILE")
    NEWLOG="${LOGFILE%.log}-${mod_date}.log"

    if [ -f "${NEWLOG}" ]; then  # in case ntp has reset time and log exists
        NEWLOG="${LOGFILE%.log}-${mod_date}_1.log"
    fi
    cp "$LOGFILE" "${NEWLOG}"
fi

> "$LOGFILE"
function litp() {
        STEP=$(( ${STEP} + 1 ))
        printf "Step %03d: litp %s\n" $STEP "$*" | tee -a "$LOGFILE"
        
        result=$(command litp "$@" | tee -a "$LOGFILE")
        if echo "$result" | grep -i error; then
                exit 1;
        fi
}


# ---------------------------------------------
# DEFINITION STARTS HERE
# ---------------------------------------------

#
# Please refer to documentation for naming conventions (we should create it)
# https://team.ammeon.com/confluence/display/LITPExt/Naming+Conventions
# E.g. the URI part cannot contain dashes (-)
#

# ---------------------------------------------
# CREATE SITE AND CLUSTER DEFINITIONS
# ---------------------------------------------

#
# Create the site definition where our cluster will be hosted
#
litp /definition/site1 create core.LitpSiteDef

# 
# Create the cluster and add all the nodes in it.
# Names sc1, sc2, pl3 etc are inticative for the node's role and not the hostname
#
litp /definition/site1/cluster1 create core.LitpClusterDef type=cmw.CmwCluster
litp /definition/site1/cluster1/sc1 create core.LitpNodeDef nodetype="control"
litp /definition/site1/cluster1/sc2 create core.LitpNodeDef nodetype="control"
#litp /definition/site1/cluster1/pl3 create core.LitpNodeDef nodetype="payload"
#litp /definition/site1/cluster1/pl4 create core.LitpNodeDef nodetype="payload"
litp /definition/site1/cluster1/nfs1 create core.LitpNodeDef

# MS1 shouldn't be part of the cluster as it's the server managing the cluster
# This is a workaround for the known bug LITP-xxxx
litp /definition/site1/cluster1/ms1 create core.LitpNodeDef nodetype="management"

# ---------------------------------------------
# DEFINE OPERATING SYSTEM ROLE(S)
# ---------------------------------------------

#
# Define an OS role with a reference to the distro that will be added to 
# Cobbler (e.g. 'node-iso-x86_64')
#
litp /definition/os create core.LitpRoleDef type=operatingsystem.GenericOS profile='linux'
litp /definition/os/rhel create core.LitpRoleDef type=operatingsystem.GenericOS profile='node-iso-x86_64'
litp /definition/os/ip create core.LitpResourceDef pool=network type=network.IPAddress
litp /definition/os/system create core.LitpResourceDef pool=systems type=hardware.GenericSystem
litp /definition/os/ks create core.LitpResourceDef type=kickstart.Kickstart
litp /definition/os/ntp1 create core.LitpResourceDef type=ntp.NtpClient
litp /definition/os/osms create core.LitpRoleDef type=operatingsystem.GenericOS profile='node-iso-x86_64'
litp /definition/os/osmn create core.LitpRoleDef type=operatingsystem.GenericOS profile='node-iso-x86_64'
litp /definition/os/osnfs create core.LitpRoleDef type=operatingsystem.GenericOS profile='node-iso-x86_64'

# ---------------------------------------------
# DEFINE A SUPERVISOR ROLE (HYPERIC)
# ---------------------------------------------

#
# Define Hyperic server role setup
#
litp /definition/hyperics create core.LitpRoleDef type=core.LitpRole
litp /definition/hyperics/hyserver create core.LitpResourceDef type=hyperic.HyServer

# Add reference to the "hyperic server role" for the MS node
litp /definition/site1/cluster1/ms1/hypericserver create core.LitpRoleReference role=hyperics

#
# Define Hyperic agent role setup
#
litp /definition/hyperica create core.LitpRoleDef type=core.LitpRole
litp /definition/hyperica/hyagent create core.LitpResourceDef type=hyperic.HyAgent

# Add reference to the "hyperic agent role"
litp /definition/site1/cluster1/ms1/hypericagent create core.LitpRoleReference role=hyperica
litp /definition/site1/cluster1/sc1/hypericagent create core.LitpRoleReference role=hyperica
litp /definition/site1/cluster1/sc2/hypericagent create core.LitpRoleReference role=hyperica
#litp /definition/site1/cluster1/pl3/hypericagent create core.LitpRoleReference role=hyperica
#litp /definition/site1/cluster1/pl4/hypericagent create core.LitpRoleReference role=hyperica


# ---------------------------------------------
# DEFINE A BOOT MANAGER ROLE
# ---------------------------------------------

#
# Define a boot manager (Cobbler Service) and the Kickstart manager running on 
# the MS.
#
litp /definition/cobbler create core.LitpRoleDef type=core.LitpRole
litp /definition/cobbler/bootservice create core.LitpServiceDef type=cobbler_server.CobblerService name="bootservice"
litp /definition/cobbler/ksmanager create core.LitpResourceDef type=cobbler_server.KickstartManager

#
# Assign the boot manager to the Managing Server (MS), by creating a role
# reference.
#
litp /definition/site1/cluster1/ms1/ms_boot create core.LitpRoleReference role=cobbler


# ---------------------------------------------
# DEFINE A HYPERVISOR ROLE
# ---------------------------------------------

#
# Create the Hypervisor role with reference to libvirt.
#
litp /definition/libvirt create core.LitpRoleDef type=core.LitpRole
litp /definition/libvirt/vmservice create core.LitpResourceDef type=virt.VMService

#
# Create a reference to the Hypervisor role for the MS node.
#
litp /definition/site1/cluster1/ms1/libvirt create core.LitpRoleReference role=libvirt


# ---------------------------------------------
# DEFINE TROUBLESHOOTING TOOLS ROLE
# ---------------------------------------------

#
# Create Troubleshooting Tools role
#
litp /definition/troubleshooting create core.LitpRoleDef type=core.LitpRole
litp /definition/troubleshooting/tool1 create core.LitpResourceDef type=litputil.Package name="sysstat" ensure="installed"
litp /definition/troubleshooting/tool2 create core.LitpResourceDef type=litputil.Package name="procps" ensure="installed"
litp /definition/troubleshooting/tool3 create core.LitpResourceDef type=litputil.Package name="bind-utils" ensure="installed"
litp /definition/troubleshooting/tool4 create core.LitpResourceDef type=litputil.Package name="lsof" ensure="installed"
litp /definition/troubleshooting/tool5 create core.LitpResourceDef type=litputil.Package name="ltrace" ensure="installed"
litp /definition/troubleshooting/tool6 create core.LitpResourceDef type=litputil.Package name="screen" ensure="installed"
litp /definition/troubleshooting/tool7 create core.LitpResourceDef type=litputil.Package name="strace" ensure="installed"
litp /definition/troubleshooting/tool8 create core.LitpResourceDef type=litputil.Package name="tcpdump" ensure="installed"
litp /definition/troubleshooting/tool9 create core.LitpResourceDef type=litputil.Package name="traceroute" ensure="installed"
litp /definition/troubleshooting/tool10 create core.LitpResourceDef type=litputil.Package name="vim-enhanced" ensure="installed"

litp /definition/troubleshooting/perm1 create core.LitpResourceDef type=litputil.File path="/usr/bin/dig" mode="700"
litp /definition/troubleshooting/perm2 create core.LitpResourceDef type=litputil.File path="/usr/bin/host" mode="700"
litp /definition/troubleshooting/perm3 create core.LitpResourceDef type=litputil.File path="/usr/sbin/lsof" mode="700"
litp /definition/troubleshooting/perm4 create core.LitpResourceDef type=litputil.File path="/usr/bin/ltrace" mode="700"
litp /definition/troubleshooting/perm5 create core.LitpResourceDef type=litputil.File path="/usr/bin/sar" mode="700"
litp /definition/troubleshooting/perm6 create core.LitpResourceDef type=litputil.File path="/usr/bin/screen" mode="700"
litp /definition/troubleshooting/perm7 create core.LitpResourceDef type=litputil.File path="/usr/bin/strace" mode="700"
litp /definition/troubleshooting/perm8 create core.LitpResourceDef type=litputil.File path="/usr/sbin/tcpdump" mode="700"
litp /definition/troubleshooting/perm9 create core.LitpResourceDef type=litputil.File path="/bin/traceroute" mode="700"
litp /definition/troubleshooting/perm10 create core.LitpResourceDef type=litputil.File path="/usr/bin/vim" mode="700"


#
# Create a reference to the "troubleshooting role" for each node.
#
litp /definition/site1/cluster1/ms1/troubleshooting create core.LitpRoleReference role=troubleshooting
litp /definition/site1/cluster1/sc1/troubleshooting create core.LitpRoleReference role=troubleshooting
litp /definition/site1/cluster1/sc2/troubleshooting create core.LitpRoleReference role=troubleshooting
#litp /definition/site1/cluster1/pl3/troubleshooting create core.LitpRoleReference role=troubleshooting
#litp /definition/site1/cluster1/pl4/troubleshooting create core.LitpRoleReference role=troubleshooting


# ---------------------------------------------
# DEFINE A MYSQL SERVER ROLE
# ---------------------------------------------

#
# Create mysql-server role
#
litp /definition/mysqlserver create core.LitpRoleDef type=core.LitpRole
litp /definition/mysqlserver/config create core.LitpResourceDef type=mysql.MYSQLServer

#
# Create a reference to the "mysql-server role" for the MS node.
#
litp /definition/site1/cluster1/ms1/mysqlserver create core.LitpRoleReference role=mysqlserver


# ---------------------------------------------
# DEFINE PUPPET DASHBOARD ROLE
# ---------------------------------------------

#
# Create puppet-dashboard role
#
litp /definition/puppetdashboard create core.LitpRoleDef type=core.LitpRole
litp /definition/puppetdashboard/config create core.LitpResourceDef  type=puppet_server.PuppetDashboard

#
# Create a reference to the "puppet-dashboard role" for the MS node.
#
litp /definition/site1/cluster1/ms1/puppetdashboard create core.LitpRoleReference role=puppetdashboard


# -------------------------------------------------
# DEFINE NFS SERVICE AND NFS CLIENT ROLES
# -------------------------------------------------

#
# nas.NASService allows the LITP designer to specify the nfs server details.
# The "share" parameter is the unique identifier that
# collates the mountpoints defined with nas.NASClient on the clients with the
# exported filesystems on the SFS server.
#
litp /definition/nasinfo create core.LitpRoleDef type=core.LitpRole
litp /definition/nasinfo/export1 create core.LitpResourceDef type=nas.NASService path="/exports/cluster" options="rw,sync,no_root_squash" share="int_cluster"

#
# Define nfs server Role - only needed for RHEL nfs this makes sure that the nfs daemon and required
# packages are online on the RHEL nfs server
#
litp /definition/nfssystem create core.LitpRoleDef type=core.LitpRole
litp /definition/nfssystem/rhel create core.LitpResourceDef type=nas.RHELServer

# This role is assigned to MS not to make it an NFS server but rather as a holder
# of the information for other nodes to refer to.
litp /definition/site1/cluster1/ms1/sfs create core.LitpRoleReference role=nasinfo

#
# Create a reference to the "NFS Service" for the MS node and NFS system for nfs node.
#
litp /definition/site1/cluster1/nfs1/nfssystem create core.LitpRoleReference role=nfssystem
 
#
# Create the SFS client role for Core Middleware.
# SIZE is per node, N nodes will require (2G + 2G + 2G) = Nx6G on the SFS server
#
litp /definition/sfs_client create core.LitpRoleDef type=core.LitpRole
litp /definition/sfs_client/sfs_share_1 create core.LitpResourceDef type=nas.NASClient mountpoint="/cluster" share="int_cluster" shared_size="6G" ip_id="ip"

#
# Reference the above resources to the Managed Nodes
#
litp /definition/site1/cluster1/sc1/sfs create core.LitpRoleReference role=sfs_client
litp /definition/site1/cluster1/sc2/sfs create core.LitpRoleReference role=sfs_client
#litp /definition/site1/cluster1/pl3/sfs create core.LitpRoleReference role=sfs_client
#litp /definition/site1/cluster1/pl4/sfs create core.LitpRoleReference role=sfs_client


# -------------------------------------------------
# DEFINE YUM REPOSITORY ROLE
# -------------------------------------------------

#
# Create a role for facilitating YUM Repositories.
#
litp /definition/repository create core.LitpRoleDef type=core.LitpRole

litp /definition/repository/repo1 create core.LitpResourceDef type=litputil.Repository name="Ammeon_LITP"
litp /definition/repository/repo2 create core.LitpResourceDef type=litputil.Repository name="Ammeon_Custom"
litp /definition/repository/repo3 create core.LitpResourceDef type=litputil.Repository name="RHEL_6.2"

# Reference that role to all nodes.
litp /definition/site1/cluster1/ms1/repository create core.LitpRoleReference role=repository
litp /definition/site1/cluster1/sc1/repository create core.LitpRoleReference role=repository
litp /definition/site1/cluster1/sc2/repository create core.LitpRoleReference role=repository
#litp /definition/site1/cluster1/pl3/repository create core.LitpRoleReference role=repository
#litp /definition/site1/cluster1/pl4/repository create core.LitpRoleReference role=repository
litp /definition/site1/cluster1/nfs1/repository create core.LitpRoleReference role=repository


# -------------------------------------------------
# DEFINE LDE (TIPC) SUPPORT ROLE
# -------------------------------------------------

#
# Create LDE role for CMW and reference this role to a pool of tipc addresses.
# Pools are part of the inventory.
#
litp /definition/lde create core.LitpRoleDef type=cmw.Lde
litp /definition/lde/tipc create core.LitpResourceDef pool=tipc type=network.TipcAddress

#
# Refernce LDE role for all MNs (Managed Nodes) 
#
litp /definition/site1/cluster1/sc1/lde create core.LitpRoleReference role=lde
litp /definition/site1/cluster1/sc2/lde create core.LitpRoleReference role=lde
#litp /definition/site1/cluster1/pl3/lde create core.LitpRoleReference role=lde
#litp /definition/site1/cluster1/pl4/lde create core.LitpRoleReference role=lde


# -----------------------------------------------------------
# DEFINE CAMPAIGN INSTALLER ROLE AND CAMPAIGN BUNDLES
# -----------------------------------------------------------

#
# Order is important when campaigns have dependencies on other campaigns.
# Order is based on the ascending sort order of the resource's definition names
#
litp /definition/cmw_installer create core.LitpRoleDef type=cmw.Cmw
litp /definition/cmw_installer/camp1 create core.LitpResourceDef type=cmw.Campaign bundle_name="ERIC-opendj-CXP_1234567_1-R1A01" install_name="ERIC-opendj-I-CXP_1234567_1-R1A01"      # opendj (on 2 Nodes SC-1, SC-2)
litp /definition/cmw_installer/camp2 create core.LitpResourceDef type=cmw.Campaign bundle_name="ERIC-jbosseap-CXP_1234567_1-R1A01" install_name="ERIC-jbosseap-I2-CXP_1234567_1-R1A01"   # jboss 6.0 EAP (on 4 Nodes SC-1, SC-2, PL-3, PL-4)
litp /definition/cmw_installer/camp3 create core.LitpResourceDef type=cmw.Campaign bundle_name="ERIC-examplelog-CXP123456_1-R1A01" install_name="ERIC-examplelog-I2-CXP123456_1-R1A01" # jboss example app on 4 Nodes
################New Pm Application campaigns #####################################
#
litp /definition/cmw_installer/camp4 create core.LitpResourceDef type=cmw.Campaign bundle_name="ERICpmmedcore_CXP9030102-2.0.7-1" bundle_type="rpm" install_name="ERIC-MedCore-Campaign"
litp /definition/cmw_installer/camp5 create core.LitpResourceDef type=cmw.Campaign bundle_name="ERICpmservice_CXP9030101-2.0.7-1" bundle_type="rpm" install_name="ERIC-PMService-Campaign"
litp /definition/cmw_installer/camp6 create core.LitpResourceDef type=cmw.Campaign bundle_name="ERICpmmedcom_CXP9030103-2.0.8-1" bundle_type="rpm" install_name="ERIC-MedService-Campaign"



#
# Assign CMW installer role to the cluster
#
litp /definition/site1/cluster1/cmw_installer create core.LitpRoleReference role=cmw_installer


# -----------------------------------------------------------
# DEFINE ROLES FOR USERS, GROUPS AND SUDOERS
# -----------------------------------------------------------

# LITP Users Role
litp /definition/rd_users create core.LitpRoleDef type=core.LitpRole

# Create the Group resource definition with a Group ID = 481
# (we'll later add user "litp_user" to that group)
litp /definition/rd_users/group_litp_user create core.LitpResourceDef type=uam.Group name=litp_user gid="481"

#
# Create the users resource definitions
#

litp /definition/rd_users/litp_admin create core.LitpResourceDef type=uam.User name=litp_admin umask="022" home="/users/litp_admin" uid="480" gid="0" seluser="unconfined_u"
litp /definition/rd_users/litp_user create core.LitpResourceDef type=uam.User name=litp_user umask="022" home="/users/litp_user" uid="481" gid="481" seluser="user_u"


# Assign the LITP Users Role to each of the nodes.
litp /definition/site1/cluster1/ms1/users create core.LitpRoleReference role=rd_users
litp /definition/site1/cluster1/sc1/users create core.LitpRoleReference role=rd_users
litp /definition/site1/cluster1/sc2/users create core.LitpRoleReference role=rd_users
#litp /definition/site1/cluster1/pl3/users create core.LitpRoleReference role=rd_users
#litp /definition/site1/cluster1/pl4/users create core.LitpRoleReference role=rd_users

#
# Define Sudoers Role (rd_sudoers)
#
litp /definition/rd_sudoers create core.LitpRoleDef type=core.LitpRole

#
# Define the resource that will manage /etc/sudoers
#
litp /definition/rd_sudoers/sudo_main create core.LitpResourceDef type=sudoers.sudoersmain.SudoersMain name=sudo_main

#
# Create the resource definitions for individual rules in /etc/sudoers.d
#
litp /definition/rd_sudoers/sudo_admin create core.LitpResourceDef type=sudoers.sudoers.Sudoers sudorole="ADMIN" users="litp_admin" cmds="/usr/sbin/useradd,/usr/sbin/userdel,/usr/sbin/groupadd,/usr/sbin/groupdel,/bin/cat,/usr/sbin/litpedit,/bin/sed" requirePasswd="FALSE" 
litp /definition/rd_sudoers/sudo_backup create core.LitpResourceDef type=sudoers.sudoers.Sudoers sudorole="BACKUP" users="litp_admin,litp_user" cmds="/usr/bin/netbackup" requirePasswd="TRUE"
litp /definition/rd_sudoers/sudo_verify create core.LitpResourceDef type=sudoers.sudoers.Sudoers sudorole="VERIFY" users="litp_verify" cmds="/sbin/iptables -L" requirePasswd="FALSE"
litp /definition/rd_sudoers/sudo_troubleshoot create core.LitpResourceDef type=sudoers.sudoers.Sudoers sudorole="TROUBLESHOOT" users="litp_admin" cmds="/usr/bin/dig,/usr/bin/host,/usr/sbin/lsof,/usr/bin/ltrace,/usr/bin/sar,/usr/bin/screen,/usr/bin/strace,/usr/sbin/tcpdump,/bin/traceroute,/usr/bin/vim,/sbin/service,/bin/mount,/bin/umount,/usr/bin/virsh,/bin/kill,/sbin/reboot,/sbin/shutdown,/usr/bin/pkill,/sbin/pvdisplay,/sbin/dmsetup,/sbin/multipath,/usr/bin/cobbler,/usr/bin/tail,/sbin/vgdisplay,/sbin/lvdisplay,/bin/rm,/opt/ericsson/nms/litp/litp_landscape/landscape,/usr/bin/which,/sbin/lltconfig,/sbin/gabconfig,/opt/VRTSvcs/bin/hastatus,/opt/VRTSvcs/bin/hacf" requirePasswd="TRUE"

#
# Assign Sudo Role Definition (rd_sudoers) to each of the nodes (node/sudoers is the Role Reference).
#
litp /definition/site1/cluster1/ms1/rd_sudoers create core.LitpRoleReference role=rd_sudoers
litp /definition/site1/cluster1/sc1/rd_sudoers create core.LitpRoleReference role=rd_sudoers
litp /definition/site1/cluster1/sc2/rd_sudoers create core.LitpRoleReference role=rd_sudoers
#litp /definition/site1/cluster1/pl3/rd_sudoers create core.LitpRoleReference role=rd_sudoers
#litp /definition/site1/cluster1/pl4/rd_sudoers create core.LitpRoleReference role=rd_sudoers


# -----------------------------------------------------------
# DEFINE ROLES SYSLOGD SERVER AND CLIENTS
# -----------------------------------------------------------

#
# Define rsyslog server role and resource definition
#
litp /definition/rd_rsyslog_server create core.LitpRoleDef type=core.LitpRole
litp /definition/rd_rsyslog_server/rsyslog_server create core.LitpResourceDef type=rlogging.Rlogserver rlport="514" rlLogsizeCluster="1G" rlAppLogsizeCluster="512M"

#
# Define rsyslog client role and resource definition
# (rlCentralHost is set to the hostname of the central log server)
#
litp /definition/rd_rsyslog_client create core.LitpRoleDef type=core.LitpRole
litp /definition/rd_rsyslog_client/rsyslog_client create core.LitpResourceDef type=rlogging.Rlogclient rlCentralPort="514" rlCentralHost="SC-1" rlSpoolSize="1000M" rlLogsizeLocal="100M" rlAppLogsizeLocal="50M"

#
# The rsyslog centralised server is assigned to SC-1
#
litp /definition/site1/cluster1/sc1/syslog_central create core.LitpRoleReference role=rd_rsyslog_server

# Make all managed nodes (MNs) and the managing server (MS) rsyslog clients  
litp /definition/site1/cluster1/sc2/syslog create core.LitpRoleReference role=rd_rsyslog_client
#litp /definition/site1/cluster1/pl3/syslog create core.LitpRoleReference role=rd_rsyslog_client
#litp /definition/site1/cluster1/pl4/syslog create core.LitpRoleReference role=rd_rsyslog_client
litp /definition/site1/cluster1/ms1/syslog create core.LitpRoleReference role=rd_rsyslog_client

# ---------------------------------------------
# DEFINE A FIREWALLSMAIN ROLE
# ---------------------------------------------

#
# Create firewallsmain role
#
litp /definition/firewallsmain create core.LitpRoleDef type=core.LitpRole
litp /definition/firewallsmain/config create core.LitpResourceDef type=firewalls.FirewallsMain

#
# Create a reference to the "firewallsmain role" for the all nodes
#
litp /definition/site1/cluster1/ms1/firewallsmain create core.LitpRoleReference role=firewallsmain
litp /definition/site1/cluster1/sc1/firewallsmain create core.LitpRoleReference role=firewallsmain
litp /definition/site1/cluster1/sc2/firewallsmain create core.LitpRoleReference role=firewallsmain
#litp /definition/site1/cluster1/pl3/firewallsmain create core.LitpRoleReference role=firewallsmain
#litp /definition/site1/cluster1/pl4/firewallsmain create core.LitpRoleReference role=firewallsmain
litp /definition/site1/cluster1/nfs1/firewallsmain create core.LitpRoleReference role=firewallsmain

# ---------------------------------------------
# DEFINE FIREWALLS RULES AND OS ROLE REFERENCES
# ---------------------------------------------

#
# Create rules and a reference to the OS role for MS
#
litp /definition/firewallsMS create core.LitpRoleDef type=core.LitpRole

litp /definition/os/osms/fw_basetcp create core.LitpResourceDef type=firewalls.Firewalls name="001 basetcp" dport="22,80,111,443,3000,25151,9999"
litp /definition/os/osms/fw_nfstcp create core.LitpResourceDef type=firewalls.Firewalls name="002 nfstcp" dport="662,875,2020,2049,4001,4045"
litp /definition/os/osms/fw_hyperic create core.LitpResourceDef type=firewalls.Firewalls name="003 hyperic" dport="2144,7080,7443"
litp /definition/os/osms/fw_syslog create core.LitpResourceDef type=firewalls.Firewalls name="004 syslog" dport="514"
litp /definition/os/osms/fw_baseudp create core.LitpResourceDef type=firewalls.Firewalls name="010 baseudp" dport="67,69,123,623,25151" proto="udp"
litp /definition/os/osms/fw_nfsudp create core.LitpResourceDef type=firewalls.Firewalls name="011 nfsudp" dport="662,875,2020,2049,4001,4045" proto="udp"
litp /definition/os/osms/fw_icmp create core.LitpResourceDef type=firewalls.Firewalls name="100 icmp" proto="icmp"

litp /definition/site1/cluster1/ms1/os create core.LitpRoleReference role=os/osms

#
# Create rules and a reference to the OS role for MNs
#
litp /definition/os/osmn/fw_basetcp create core.LitpResourceDef type=firewalls.Firewalls name="001 basetcp" dport="21,22,80,111,161,162,443,1389,3000,25151,9999"
litp /definition/os/osmn/fw_nfstcp create core.LitpResourceDef type=firewalls.Firewalls name="002 nfstcp" dport="662,875,2020,2049,4001,4045"
litp /definition/os/osmn/fw_hyperic create core.LitpResourceDef type=firewalls.Firewalls name="003 hyperic" dport="2144,7080,7443"
litp /definition/os/osmn/fw_syslog create core.LitpResourceDef type=firewalls.Firewalls name="004 syslog" dport="514"
#litp /definition/os/osmn/fw_jboss create core.LitpResourceDef type=firewalls.Firewalls name="005 jboss" dport="8080,9990,9876,54321"
litp /definition/os/osmn/fw_jboss create core.LitpResourceDef type=firewalls.Firewalls name="005 jboss" dport="4447,8080,9990,9876,45688,45700,54321"
litp /definition/os/osmn/fw_baseudp create core.LitpResourceDef type=firewalls.Firewalls name="010 baseudp" dport="111,123,623,1129,9876,25151" proto="udp"
litp /definition/os/osmn/fw_nfsudp create core.LitpResourceDef type=firewalls.Firewalls name="011 nfsudp" dport="662,875,2020,2049,4001,4045" proto="udp"
litp /definition/os/osmn/fw_icmp create core.LitpResourceDef type=firewalls.Firewalls name="100 icmp" proto="icmp"

litp /definition/site1/cluster1/sc1/os create core.LitpRoleReference role=os/osmn
litp /definition/site1/cluster1/sc2/os create core.LitpRoleReference role=os/osmn
#litp /definition/site1/cluster1/pl3/os create core.LitpRoleReference role=os/osmn
#litp /definition/site1/cluster1/pl4/os create core.LitpRoleReference role=os/osmn

#
# Create rules and a reference to the OS role for NFS
#
litp /definition/os/osnfs/fw_basetcp create core.LitpResourceDef type=firewalls.Firewalls name="001 basetcp" dport="22,80,111,161,162,443,3000,9999"
litp /definition/os/osnfs/fw_nfstcp create core.LitpResourceDef type=firewalls.Firewalls name="002 nfstcp" dport="662,875,2020,2049,4001,4045"
litp /definition/os/osnfs/fw_syslog create core.LitpResourceDef type=firewalls.Firewalls name="003 syslog" dport="514"
litp /definition/os/osnfs/fw_baseudp create core.LitpResourceDef type=firewalls.Firewalls name="010 baseudp" dport="111,123,623" proto="udp"
litp /definition/os/osnfs/fw_nfsudp create core.LitpResourceDef type=firewalls.Firewalls name="011 nfsudp" dport="662,875,2020,2049,4001,4045" proto="udp"
litp /definition/os/osnfs/fw_icmp create core.LitpResourceDef type=firewalls.Firewalls name="100 icmp" proto="icmp"

litp /definition/site1/cluster1/nfs1/os create core.LitpRoleReference role=os/osnfs

# -----------------------------------------------------------
# MATERIALISE THE DEFINITION
# -----------------------------------------------------------

# Instantiate (materialise) the Roles/Resources for Site1 within the Landscape
# This will create the placeholders for resources under the /inventory  with
# empty properties that will be filled by elements in the Inventory Section

litp /definition/site1 materialise

# ---------------------------------------------
# DEFINITION ENDS HERE
# ---------------------------------------------

# Let's guide the user for the next step (messages need to be improved)
echo "The definition part is completed."
echo "Next step is to run the inventory part"

exit 0
