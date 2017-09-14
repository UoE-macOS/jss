#!/bin/sh

###################################################################
#
# Delete old LCFG installation
# This is an import of Kenny's script from
# https://sourced.ecdf.ed.ac.uk/projects/is/dst/browser/macosx/trunk/UoE-Welcome/scripts/delete-lcfg
#
# Date: "Fri 18 Aug 16:26:38 2016 +0100"
# Version: 0.1.4
# Origin: https://github.com/UoE-macOS/jss.git
# Released by JSS User: dsavage
#
##################################################################

echo Removing old LCFG installation ...

_lcfg_pkgs () {
    pkgutil --packages | grep -E '^org\.(lcfg\.|cpan\.W3C-)'
}

_pkg_files () {
    pkgutil --lsbom ${1} | sed s'/^\.//' | grep -v ^$ | sort -ur
}

_forget_pkg () {
    pkgutil --forget ${1}
}

_check_file () {
    # Return true if file ($1) belongs only to pkg ($2)
    local id
    # Skip testing for system dirs to speed up processing
    case "${1}" in
	/|/usr|/usr/bin|/usr/lib|/usr/local|/usr/sbin|/usr/share|/usr/share/doc|/usr/share/man|/usr/share/man/man?|/var|/Library|/Library/Perl|/Library/Perl/5.??)
	    return 1
	    ;;
    esac
    id=`pkgutil --file-info ${1} | grep ^pkgid: | sed 's/^pkgid: //'`
    [ "${id}" ] && [ "${id}" == "${2}" ] && return 0
    return 1
}
	
_delete_pkg () {
    # Remove all the files first ...
    local file lcfg_dirs dir
    for file in `_pkg_files ${1}`
    do
        if [ -f ${file} ]
				then
            _check_file ${file} ${1} && rm ${file} 2>/dev/null
				else
					if [ -d "${file}" ]
					then
						lcfg_dirs="${lcfg_dirs} ${file}"
					fi
				fi
    done
    
    for dir in ${lcfg_dirs}
    do
			_check_file ${dir} ${1} && rmdir ${dir} 2>/dev/null
    done

    _forget_pkg ${1}
}


_delete_mcx() {

dscl . -destroy /ComputerGroups/org.lcfg.mcx.00-dockithelp
rm -dfR /Library/Managed\ Preferences

}


_delete_lcfg() {

    local p
    
    [ -f "/var/lcfg/conf/profile/nodename" ] && cat /var/lcfg/conf/profile/nodename > /var/db/.MigratingFromLCFG 2>/dev/null
    # Try stopping lcfg first
    PATH=$PATH:/usr/local/bin:/usr/local/sbin
    om client stop
    
    # Remove some directories we know are only from LCFG
    rm -rf  /var/lcfg \
        /usr/{,local}/lib/lcfg \
        /usr/{,local/}bin/qx{pack,prof} \
        /usr/{,local/}bin/sxprof \
        /usr/{,local}/{s,}bin/lcfg* \
        /usr/{,local}/sbin/rdxprof \
        /usr/{,local}/include/lcfg* \
        /usr/local/share/man/man*/{lcfg,LCFG}* \
        /usr/{,local}/share/doc/lcfg-* \
        /usr/{,local}/share/lcfgbuild \
        /etc/logrotate.d/lcfg-* \
        /Library/LaunchAgents/ed.is.enable_web_java_plugin.plist \
        /Library/LaunchAgents/ed.is.personalizeoffice.plist \
        /Library/LaunchDaemons/*lcfg \
        /Library/LaunchDaemons/ed.is.AddPrinter.plist \
        /Library/LaunchDaemons/ed.is.Bomgar-SocketFilterFW.plist \
        /Library/LaunchDaemons/ed.is.FlashWatchman.plist \
        /Library/LaunchDaemons/ed.is.lcfg_client_check.plist \
        /Library/LaunchDaemons/ed.is.MacOSWatchman.plist \
        /Library/LaunchDaemons/ed.is.remove-mso2011.plist \
        /Library/LaunchDaemons/ed.is.setcomputername.plist \
        /Library/LaunchDaemons/ed.is.setlocalhostname.plist \
        /Library/LaunchDaemons/ed.is.softwareupdate.plist \
        /Library/LaunchDaemons/ed.is.XeroxWatchman.plist \
        /Library/LaunchDaemons/ed.msd.HomeSyncDaemon.plist \
        /Library/LaunchDaemons/swupdate.plist \
        /Library/LaunchDaemons/uk.ac.ed.mdp.rebootd.plist \
        /Library/MacMDP/Receipts/* \
        /Library/StartupItems/MacLCFG \
        /Library/StartupItems/InstallLCFGProfile \
        /etc/cups/lcfg* \
        /usr/{,local}/share/man/man*/lcfg-* \
        2>/dev/null

    # Delete remaining files from all LCFG packages, and forget them
    # too.
    for p in `_lcfg_pkgs` ; do _delete_pkg ${p}; done
    
    [ -f "/var/db/.MigratingFromLCFG" ] && mv /var/db/.MigratingFromLCFG /var/db/MigratedFromLCFG || exit 0
}

# Call the main function ...
_delete_lcfg
_delete_mcx
