# See README.me for usage.
class mysql::backup::xtrabackup (
  $xtrabackup_package_name = $mysql::params::xtrabackup_package_name,
  $backupuser              = '',
  $backuppassword          = '',
  $backupdir               = '',
  $maxallowedpacket        = '1M',
  $backupmethod            = 'mysqldump',
  $backupdirmode           = '0700',
  $backupdirowner          = 'root',
  $backupdirgroup          = $mysql::params::root_group,
  $backupcompress          = true,
  $backuprotate            = 30,
  $ignore_events           = true,
  $delete_before_dump      = false,
  $backupdatabases         = [],
  $file_per_database       = false,
  $include_triggers        = true,
  $include_routines        = false,
  $ensure                  = 'present',
  $time                    = ['23', '5'],
  $prescript               = false,
  $postscript              = false,
  $execpath                = '/usr/bin:/usr/sbin:/bin:/sbin',
  $optional_args           = [],
  $healthcheckio_uuid      = '',
) inherits mysql::params {

  package{ $xtrabackup_package_name:
    ensure  => $ensure,
  }

  if $backupuser and $backuppassword {
    mysql_user { "${backupuser}@localhost":
      ensure        => $ensure,
      password_hash => mysql_password($backuppassword),
      require       => Class['mysql::server::root_password'],
    }

    mysql_grant { "${backupuser}@localhost/*.*":
      ensure     => $ensure,
      user       => "${backupuser}@localhost",
      table      => '*.*',
      privileges => [ 'RELOAD', 'LOCK TABLES', 'REPLICATION CLIENT' ],
      require    => Mysql_user["${backupuser}@localhost"],
    }
  }

  xtrabackup-weekly-cmd = "/usr/local/sbin/xtrabackup.sh ${backupdir}"
  xtrabackup-daily-cmd  = "/usr/local/sbin/xtrabackup.sh --incremental ${backupdir} --incremental-basedir ${backupdir}/$(ls -1rt ${backupdir} | tail -1)"

  if ($healthcheckio_uuid != '' ) {
    healthcheckio_curl = "curl -fsS -m 10 --retry 5 -o /dev/null https://hc-ping.com/${healthcheckio_uuid}"
    xtrabackup-weekly-cmd = "${healthcheckio_curl}/start || (${xtrabackup-weekly-cmd} && ${healthcheckio_curl})"
    xtrabackup-daily-cmd  = "${healthcheckio_curl}/start || (${xtrabackup-daily-cmd} && ${healthcheckio_curl})"
  }

  cron { 'xtrabackup-weekly':
    ensure  => $ensure,
    command => $xtrabackup-weekly-cmd,
    user    => 'root',
    hour    => $time[0],
    minute  => $time[1],
    weekday => '0',
    require => Package[$xtrabackup_package_name],
  }

  cron { 'xtrabackup-daily':
    ensure  => $ensure,
    command => $xtrabackup-daily-cmd,
    user    => 'root',
    hour    => $time[0],
    minute  => $time[1],
    weekday => '1-6',
    require => Package[$xtrabackup_package_name],
  }

  file { 'mysqlbackupdir':
    ensure => 'directory',
    path   => $backupdir,
    mode   => $backupdirmode,
    owner  => $backupdirowner,
    group  => $backupdirgroup,
  }

  file { 'xtrabackup.sh':
    ensure  => $ensure,
    path    => '/usr/local/sbin/xtrabackup.sh',
    mode    => '0700',
    owner   => 'root',
    group   => $mysql::params::root_group,
    content => template('mysql/xtrabackup.sh.erb'),
  }
}
