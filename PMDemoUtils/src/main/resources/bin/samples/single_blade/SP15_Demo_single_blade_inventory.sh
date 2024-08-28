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
# landscape log file in the user's current directory. Can safely be removed 
# if not needed.

STEP=0
LOGDIR="logs"
if [ ! -d "$LOGDIR" ]; then
    mkdir $LOGDIR
fi
LOGFILE="${LOGDIR}/landscape_inventory.log"
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


# --------------------------------------------
# INVENTORY STARTS HERE
# --------------------------------------------

# ---------------------------------------------
# UPDATE NFS SERVER DETAILS
# ---------------------------------------------

# "SFS" driver is used for NAS storage device and "RHEL" for when an extra RHEL
# Linux node is used. 
# password is only needed if ssh keys have not been setup up ( ie in case of SFS )
litp /inventory/site1/cluster1/ms1/sfs/export1 update driver="RHEL" user="root" password="cobbler" server="NFS-1"

# ---------------------------------------------
# CREATE AN IP ADDRESS POOL
# ---------------------------------------------

litp /inventory/site1/network create network.IPAddressPool

# Add available addresses to the network by creating a pool
litp /inventory/site1/network/range1 create network.IPAddressPool subnet=10.45.236.0/22 start=10.45.236.7 end=10.45.236.11 gateway=10.45.236.1
litp /inventory/site1/network/ip_10_45_236_6 create network.IPAddress subnet=10.45.236.0/22 address=10.45.236.6 gateway=10.45.236.1
litp /inventory/site1/network/ip_10_45_236_6 enable

# ---------------------------------------------
# CREATE A TIPC ADDRESS POOL
# ---------------------------------------------

#
# First two addresses are reserved for sc-1 and sc-2 nodes, so we start
# assigning addresses to other nodes from 1.1.3 and after
#
litp /inventory/site1/tipc create network.TipcAddressPool netid="9005" start="3"


# ---------------------------------------------
# ADD THE PHYSICAL SERVER
# ---------------------------------------------


litp /inventory/site1/systems create hardware.GenericSystemPool
litp /inventory/site1/systems/blade create hardware.GenericSystem macaddress="44:1E:A1:52:59:C4" hostname="ms1" domain=""
litp /inventory/site1/systems/blade enable
litp /inventory/site1/systems/blade update bridge_enabled=True


# ---------------------------------------------
# ADD THE VIRTUAL NODES
# ---------------------------------------------


litp /inventory/site1/systems/vm_pool create virt.VMPool mac_start='DE:AD:BE:EF:B1:52' mac_end='DE:AD:BE:EF:B2:57'
litp /inventory/site1/systems/vm_pool update path='/var/lib/libvirt/images'
litp /inventory/site1/systems/vm_pool/hyper_visor create virt.HostAssignment host='/inventory/site1/cluster1/ms1/libvirt/vmservice'


# ---------------------------------------------
# ADD AN NTP SERVER  
# ---------------------------------------------

# Systems updating time directly from ntp server
litp /inventory/site1/cluster1/ms1/os/ntp1 update server="159.107.173.12"
litp /inventory/site1/cluster1/sc1/os/ntp1 update server="159.107.173.12"
litp /inventory/site1/cluster1/sc2/os/ntp1 update server="159.107.173.12"

# Systems updating time from within the cluster
litp /inventory/site1/cluster1/nfs1/os/ntp1 update server="SC-1,SC-2"


# ---------------------------------------------
# ADD YUM REPOSITORIES  
# ---------------------------------------------

#
# YUM repositories reside on the Managing Server, with hostname MS1
#

# YUM repository for LITP Pkgs (MS1 has repositories locally)
litp /inventory/site1/cluster1/ms1/repository/repo1 update url="file:///var/www/html/litp"
litp /inventory/site1/cluster1/sc1/repository/repo1 update url="http://MS1/litp"
litp /inventory/site1/cluster1/sc2/repository/repo1 update url="http://MS1/litp"
litp /inventory/site1/cluster1/nfs1/repository/repo1 update url="http://MS1/litp"

# YUM repository for Ammeon Custom Pkgs (MS1 has repositories locally)
litp /inventory/site1/cluster1/ms1/repository/repo2 update url="file:///var/www/html/custom"
litp /inventory/site1/cluster1/sc1/repository/repo2 update url="http://MS1/cobbler/ks_mirror/node-iso-x86_64/custom"
litp /inventory/site1/cluster1/sc2/repository/repo2 update url="http://MS1/cobbler/ks_mirror/node-iso-x86_64/custom"
litp /inventory/site1/cluster1/nfs1/repository/repo2 update url="http://MS1/cobbler/ks_mirror/node-iso-x86_64/custom"

# YUM repository for RHEL OS Pkgs (MS1 has repositories locally)
litp /inventory/site1/cluster1/ms1/repository/repo3 update url="file:///var/www/html/rhel"
litp /inventory/site1/cluster1/sc1/repository/repo3 update url="http://MS1/cobbler/ks_mirror/node-iso-x86_64"
litp /inventory/site1/cluster1/sc2/repository/repo3 update url="http://MS1/cobbler/ks_mirror/node-iso-x86_64"
litp /inventory/site1/cluster1/nfs1/repository/repo3 update url="http://MS1/cobbler/ks_mirror/node-iso-x86_64"


# Update the user's passwords
# The user's passwords must be encrypted, the encryption method is Python's 2.6.6
# crypt function. The following is an example for encrypting the phrase 'passw0rd'
#
# [cmd_prompt]$ python
# Python 2.6.6 (r266:84292, May 20 2011, 16:42:11) 
# [GCC 4.4.5 20110214 (Red Hat 4.4.5-6)] on linux2
# Type "help", "copyright", "credits" or "license" for more information.
# >>> import crypt
# >>> crypt.crypt("passw0rd")
# '$6$VbIEnv1XppQpNHel$/ikRQIa5i/cNJR2BYucNkTjHmO/HBzHdvDbsXa7fprXILrGYa.xMOPI9b.y5HrfqWHfVyfXK7AffI9DrkUBWJ.'
#
# Symbol '$' is a shell metacharacter and needs to be "escaped" with '\\\'
#
litp /inventory/site1/cluster1/ms1/users/litp_admin update password=\\\$6\\\$VbIEnv1XppQpNHel\\\$/ikRQIa5i/cNJR2BYucNkTjHmO/HBzHdvDbsXa7fprXILrGYa.xMOPI9b.y5HrfqWHfVyfXK7AffI9DrkUBWJ.
litp /inventory/site1/cluster1/ms1/users/litp_user update password=\\\$6\\\$VbIEnv1XppQpNHel\\\$/ikRQIa5i/cNJR2BYucNkTjHmO/HBzHdvDbsXa7fprXILrGYa.xMOPI9b.y5HrfqWHfVyfXK7AffI9DrkUBWJ.
litp /inventory/site1/cluster1/sc1/users/litp_admin update password=\\\$6\\\$VbIEnv1XppQpNHel\\\$/ikRQIa5i/cNJR2BYucNkTjHmO/HBzHdvDbsXa7fprXILrGYa.xMOPI9b.y5HrfqWHfVyfXK7AffI9DrkUBWJ.
litp /inventory/site1/cluster1/sc1/users/litp_user update password=\\\$6\\\$VbIEnv1XppQpNHel\\\$/ikRQIa5i/cNJR2BYucNkTjHmO/HBzHdvDbsXa7fprXILrGYa.xMOPI9b.y5HrfqWHfVyfXK7AffI9DrkUBWJ.
litp /inventory/site1/cluster1/sc2/users/litp_admin update password=\\\$6\\\$VbIEnv1XppQpNHel\\\$/ikRQIa5i/cNJR2BYucNkTjHmO/HBzHdvDbsXa7fprXILrGYa.xMOPI9b.y5HrfqWHfVyfXK7AffI9DrkUBWJ.
litp /inventory/site1/cluster1/sc2/users/litp_user update password=\\\$6\\\$VbIEnv1XppQpNHel\\\$/ikRQIa5i/cNJR2BYucNkTjHmO/HBzHdvDbsXa7fprXILrGYa.xMOPI9b.y5HrfqWHfVyfXK7AffI9DrkUBWJ.
#litp /inventory/site1/cluster1/pl3/users/litp_admin update password=\\\$6\\\$VbIEnv1XppQpNHel\\\$/ikRQIa5i/cNJR2BYucNkTjHmO/HBzHdvDbsXa7fprXILrGYa.xMOPI9b.y5HrfqWHfVyfXK7AffI9DrkUBWJ.
#litp /inventory/site1/cluster1/pl3/users/litp_user update password=\\\$6\\\$VbIEnv1XppQpNHel\\\$/ikRQIa5i/cNJR2BYucNkTjHmO/HBzHdvDbsXa7fprXILrGYa.xMOPI9b.y5HrfqWHfVyfXK7AffI9DrkUBWJ.
#litp /inventory/site1/cluster1/pl4/users/litp_admin update password=\\\$6\\\$VbIEnv1XppQpNHel\\\$/ikRQIa5i/cNJR2BYucNkTjHmO/HBzHdvDbsXa7fprXILrGYa.xMOPI9b.y5HrfqWHfVyfXK7AffI9DrkUBWJ.
#litp /inventory/site1/cluster1/pl4/users/litp_user update password=\\\$6\\\$VbIEnv1XppQpNHel\\\$/ikRQIa5i/cNJR2BYucNkTjHmO/HBzHdvDbsXa7fprXILrGYa.xMOPI9b.y5HrfqWHfVyfXK7AffI9DrkUBWJ.

# ---------------------------------------------
# CONFIGURE & ALLOCATE THE RESOURCES
# ---------------------------------------------

#
# Set MySQL Password
#
litp /inventory/site1/cluster1/ms1/mysqlserver/config update password="ammeon101"

#
# Set Hyperic username and password for the GUI
#
litp /inventory/site1/cluster1/ms1/hypericserver/hyserver update username="hqadmin" password="ammeon101"

# Specify the CMW node types
# Available roles are "control" and "payload"
litp /inventory/site1/cluster1/sc1 update nodetype="control" primarynode=true
litp /inventory/site1/cluster1/sc2 update nodetype="control"
#litp /inventory/site1/cluster1/pl3 update nodetype="payload"
#litp /inventory/site1/cluster1/pl4 update nodetype="payload"

# MS to allocate first and "secure" the blade hw for this node.
litp /inventory/site1/cluster1/ms1 allocate
litp /inventory/site1 allocate

# ------------------------------------------------------------
# SET THIS PROPERTY FOR ALL SYSTEMS NOT TO BE ADDED TO COBBLER
# ------------------------------------------------------------
litp /inventory/site1/cluster1/ms1 update add_to_cobbler="False"

# Control server need manual allocation of TIPC addresses reserved for this
# CMW role. This workaround is a CMW limitation. 
litp /inventory/site1/cluster1/sc1/lde/tipc update netid="9005" address="1.1.1" nodenumber="1"
litp /inventory/site1/cluster1/sc2/lde/tipc update netid="9005" address="1.1.2" nodenumber="2"

# Updating hostnames of the systems. 
litp /inventory/site1/cluster1/sc1/os/system update hostname="SC-1" domain="" systemname="vm_site1_cluster1_sc1"
litp /inventory/site1/cluster1/sc2/os/system update hostname="SC-2" domain="" systemname="vm_site1_cluster1_sc2"
#litp /inventory/site1/cluster1/pl3/os/system update hostname="PL-3" domain="" systemname="vm_site1_cluster1_pl3"
#litp /inventory/site1/cluster1/pl4/os/system update hostname="PL-4" domain="" systemname="vm_site1_cluster1_pl4"
litp /inventory/site1/cluster1/nfs1/os/system update hostname="NFS-1" domain="" systemname="vm_site1_cluster1_nfs1"

# Allocate some more h/w resources for VMs, by modifying default values.
# RAM size in Megabytes, disk size in Gigabytes
litp /inventory/site1/systems/vm_pool/vm_site1_cluster1_sc1 update ram='16384M' disk='80G' cpus="2"
litp /inventory/site1/systems/vm_pool/vm_site1_cluster1_sc2 update ram='16384M' disk='80G' cpus="2"
#litp /inventory/site1/systems/vm_pool/vm_site1_cluster1_pl3 update ram='2048M' disk='40G' cpus="2"
#litp /inventory/site1/systems/vm_pool/vm_site1_cluster1_pl4 update ram='2048M' disk='40G' cpus="2"
litp /inventory/site1/systems/vm_pool/vm_site1_cluster1_nfs1 update ram='8192M' disk='30G' cpus="2"

# Update kiskstart information. Convention for kickstart filenames is node's 
# hostname with a "ks" extension
litp /inventory/site1/cluster1/sc1/os/ks update ksname="SC-1.ks" path=/var/lib/cobbler/kickstarts
litp /inventory/site1/cluster1/sc2/os/ks update ksname="SC-2.ks" path=/var/lib/cobbler/kickstarts
#litp /inventory/site1/cluster1/pl3/os/ks update ksname="PL-3.ks" path=/var/lib/cobbler/kickstarts
#litp /inventory/site1/cluster1/pl4/os/ks update ksname="PL-4.ks" path=/var/lib/cobbler/kickstarts
litp /inventory/site1/cluster1/nfs1/os/ks update ksname="NFS-1.ks" path=/var/lib/cobbler/kickstarts

# Update the verify user to root. Workaround, user litp_verify doesn't exist yet
# Issue LITP-XXX (or User Story?)
litp /inventory/site1/cluster1/ms1 update verify_user="root"
litp /inventory/site1/cluster1/sc1 update verify_user="root"
litp /inventory/site1/cluster1/sc2 update verify_user="root"
#litp /inventory/site1/cluster1/pl3 update verify_user="root"
#litp /inventory/site1/cluster1/pl4 update verify_user="root"
litp /inventory/site1/cluster1/nfs1 update verify_user="root"

# Allocate the complete site
litp /inventory/site1 allocate

# --------------------------------------
# APPLY CONFIGURATION TO PUPPET
# --------------------------------------

# This is an intermediate step before applying the configuration to puppet
litp /inventory/site1 configure


# --------------------------------------
# VALIDATE INVENTORY CONFIGURATION
# --------------------------------------

litp /inventory validate

# --------------------------------------
# APPLY CONFIGURATION TO PUPPET
# --------------------------------------

# Configuration's Manager (Puppet) manifests for the inventory will be created
# after this
litp /cfgmgr apply scope=/inventory

# (check for puppet errors -> "grep puppet /var/log/messages")
# (use "service puppet restart" to force configuration now)

# --------------------------------------------
# INVENTORY ENDS HERE
# --------------------------------------------

echo "Inventory addition has completed"
echo "Please wait for puppet to configure cobbler. This should take about 3 minutes"

exit 0
