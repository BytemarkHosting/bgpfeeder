#
# Regular cron jobs for the bgpfeeder package
#
0 4	* * *	root	[ -x /usr/bin/bgpfeeder_maintenance ] && /usr/bin/bgpfeeder_maintenance
