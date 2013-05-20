define mail_server (
    $ssl_certificate,
    $ssl_certificate_key,
    $server_fqdn = $title,
    $server_origin = '(3)NXDOMAIN',
    $server_domain = '(3)NXDOMAIN',
    $destinations = [],
    $networks = [],
    $virtual_domain_users = {},
    $virtual_aliases = {},
    $virtual_uid_gid = {
        user    =>  'vmail',
        uid     =>  5000,
        group  =>  'vmail',
        gid     =>  '5000',
    },
    $virtual_mailbox_base = '/var/mail/vmail',
    $ssl_certificate = '(3)NXDOMAIN',
    $ssl_certificate_key = '(3)NXDOMAIN',
    ) {

    ####################################################################
    # Very hackish way around not being able to reassign variables.
    # Oh well.
    ####################################################################
    if $server_origin == '(3)NXDOMAIN' {
        $config_origin = $server_fqdn
    } else {
        $config_origin = $server_origin
    }

    if $server_domain == '(3)NXDOMAIN' {
        $config_domain = $server_fqdn
    } else {
        $config_domain = $server_domain
    }
    
    $config_fqdn = $server_fqdn

    if $destinations == [] {
        $config_destinations = [$config_domain,]
    } else {
        $config_destinations = $destinations
    }

    if $networks == [] {
        $config_networks = ["$ipaddress/32",]
    } else {
        $config_networks = $networks
    }
    ####################################################################

    case $::operatingsystem {
        debian, ubuntu: {
            $dovecot_pkg    =   'dovecot-imapd'
            $dovecot_cfg    =   '/etc/dovecot'
            $dovecot_svc    =   'dovecot'
            $dovecot_users  =   "$dovecot_cfg/users"

            $postfix_pkg    =   'postfix'
            $postfix_cfg    =   '/etc/postfix'
            $postfix_svc    =   'postfix'
            $postfix_maps   =   "$postfix_cfg/maps"
            $postmap        =   '/usr/sbin/postmap'
        } 
        default: { fail("Operating system unsupported: $::operatingsystem") }
    }

    $vmailbox_map = "$postfix_maps/vmailboxes.cf"
    $valias_map = "$postfix_maps/valiases.cf"

    group { $virtual_uid_gid[group]: 
        ensure      =>  present,
        gid         =>  $virtual_uid_gid[gid],
    } ->
    user { $virtual_uid_gid[user]: 
        ensure      =>  present,
        uid         =>  $virtual_uid_gid[uid],
        gid         =>  $virtual_uid_gid[gid],
        home        =>  $virtual_mailbox_base,
        managehome  =>  true,
    } ->
    file { $virtual_mailbox_base :
        ensure      =>  directory,
        owner       =>  $virtual_uid_gid[uid],
        group       =>  $virtual_uid_gid[gid],
        mode        =>  0770,
    }

    package { $dovecot_pkg :
        ensure      =>  installed,
    } ->
    file { "$dovecot_cfg/dovecot.conf" :
        ensure      =>  present,
        owner       =>  'root',
        group       =>  'root',
        mode        =>  0660,
        content     =>  template('mail_server/dovecot/dovecot.conf.erb'),
    } ->
    service { $dovecot_svc :
        ensure      =>  running,
        enable      =>  true,
        hasstatus   =>  true,
        hasrestart  =>  true,
        subscribe   =>  File["$dovecot_cfg/dovecot.conf"],
    }

    file { $dovecot_users :
        ensure      =>  present,
        owner       =>  'dovecot',
        group       =>  'root',
        mode        =>  0660,
        content     => template('mail_server/dovecot/users.erb'),
    }

    package { $postfix_pkg :
        ensure      =>  installed,
    } ->
    file { "$postfix_cfg/main.cf" :
        ensure      =>  present,
        owner       =>  'root',
        group       =>  'root',
        mode        =>  0660,
        content     =>  template('mail_server/postfix/main.cf.erb'),
    } ->
    file { "$postfix_cfg/master.cf" :
        ensure      =>  present,
        owner       =>  'root',
        group       =>  'root',
        mode        =>  0660,
        content     =>  template('mail_server/postfix/master.cf.erb'),
    } ->
    service { $postfix_svc :
        ensure      =>  running,
        enable      =>  true,
        hasstatus   =>  true,
        hasrestart  =>  true,
        subscribe   =>  [File["$postfix_cfg/main.cf"],
                         File["$postfix_cfg/master.cf"],
                         Service[$dovecot_svc],],
    } ->
    file { $postfix_maps :
        ensure      =>  directory,
        owner       =>  'postfix',
        group       =>  'root',
        mode        =>  0770,
    } ->
    # Postfix virtual mailbox maps
    file { $vmailbox_map :
        ensure      =>  present,
        owner       =>  'postfix',
        group       =>  'root',
        mode        =>  0440,
        content     =>  template('mail_server/postfix/maps/vmailboxes.cf.erb'),
    } ->
    exec { "$postmap $vmailbox_map" :
        refreshonly =>  true,
        subscribe   =>  File[$vmailbox_map],
    }
    # Postfix virtual alias maps
    file { $valias_map :
        ensure      =>  present,
        owner       =>  'postfix',
        group       =>  'root',
        mode        =>  0440,
        content     =>  template('mail_server/postfix/maps/valiases.cf.erb'),
    } ->
    exec { "$postmap $valias_map" :
        refreshonly =>  true,
        subscribe   =>  File[$valias_map],
    }
    exec { "/usr/bin/openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -keyout $ssl_certificate_key -out $ssl_certificate -batch" :
        creates     =>  $ssl_certificate,
    }
}
