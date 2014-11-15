# Puppet ``mail_server``

## Overview
Puppet ``mail_server`` is a Puppet module to enable quick deployment of a full-stack mail server using Postfix and Dovecot. It supports virtual and local mail delivery.

## Features

* Runs on Ubuntu (tested and functional on Ubuntu 14.04 as of November 15, 2014)
* Single-file basic configuration of [Postfix](http://www.postfix.org/) and [Dovecot](http://www.dovecot.org/)
* Local mail delivery to users with system accounts on administrator-specified domains
* Virtual mail delivery to users without system accounts on administrator-specified domains
* Puppet 3.1+ compatible

## Getting It
When cloning, it is important to make sure that the directory name is **exactly** ``mail_server``. This is because of how Puppet handles module and class naming.

First, ``cd`` into your Puppet module path (either ``/usr/share/puppet/modules`` or ``/etc/puppet/modules`` by default on Ubuntu):
    
    cd /usr/share/puppet/modules

Then clone over HTTPS or SSH

### HTTPS
    
    git clone https://github.com/Okomokochoko/puppet-mail-server.git mail_server

### SSH
    
    git clone git@github.com:Okomokochoko/puppet-mail-server.git mail_server

## Virtual vs Local
**Local** mail delivery is mail delivered to system-local users. For instance, if you login to your server on SSH as ``joe``, and you set your server up to allow local delivery for the domains ``example.com`` and ``coffee.com``, mail sent to ``joe@example.com`` or ``joe@coffee.com`` will be delivered to ``/home/joe/Maildir``.

**Virtual** mail delivery is mail delivered to a mail store on the server, but for users who are not given system accounts. For instance, your friend Johnny is a privacy nut and doesn't want to use Gmail, but you don't want him to have shell access to your server. You can run mail for Johnny's domain ``johnny.net`` as a "virtual domain" and accept delivery of his mail. He'll be able to login via IMAP and SMTP, but you can keep his paws far away from your command line. Mail to ``johnny.net`` accounts would be stored in ``/var/mail/vmail`` by default.

Currently, virtual configuration is file-based only (using the ``hash:`` scheme in Postfix and the ``userdb passwd-file`` scheme in Dovecot). Eventually I'm hoping to expand that to support database-backed virtual configuration.

### A WARNING
You **cannot** share a domain between local and virtual delivery. Postfix will deliver mail for a domain for either local *OR* virtual users, but not both.

## A Sample Configuration:
Let's take a look at a sample configuration. We'll call it ``my-mail-server.pp``.

    class sample_mail_server {

        # Puppet resource title ``example.net`` is the local mail domain
        mail_server { 'example.net' :
            
            # The ``ssl_*`` fields should each be an absolute path to the
            # given component of the SSL process. If these do not exist,
            # PMS will create self-signed ones, which can be replaced later.
            ssl_certificate         =>  '/etc/ssl/certs/example.net.cert',
            ssl_certificate_key     =>  '/etc/ssl/private/example.net.key',
            virtual_aliases         =>  {
                'webmaster@example.com'    =>  'webmaster',
            },

            # The ``virtual_domain_users`` hash contains a key per virtual domain
            virtual_domain_users    =>  {
                'example.com'  =>  {
                    
                    # Each domain is a hash containing a key per virtual user for that domain...
                    'test'  =>  {
                        # ...and each is a hash containing settings for each user (right now only their password)
                        'password'  =>  "{SSHA256.HEX}665ec17a01855ea9e3d5fbc52727d32af02a8b67b637d7cd6f8179634f30cdaf77b7c3b5",
                    },  
                    'another'  =>  {
                        'password'  =>  "{SSHA256.HEX}665ec17a01855ea9e3d5fbc52727d32af02a8b67b637d7cd6f8179634f30cdaf77b7c3b5",
                    },  
                },  
            },  
        }
    }
    # This line is the one that actually makes our class above do something, by including it
    include sample_mail_server

To use this configuration, you'd then run:

    $ puppet apply my-mail-server.pp

Future applications of the manifest may result in updated files as templates loop through their data hashes due to the arbitrary ordering of hash entries in Ruby.

## Generating Passwords
To generate a password, use the ``doveadm`` tool from Ubuntu's ``dovecot-imapd`` package:
    
    doveadm pw -s SSHA256.HEX

``SSHA256.HEX`` generates a salted SHA256 hexadecimal hash of the given password. There are many other schemes on Dovecot's [wiki](http://wiki2.dovecot.org/Authentication/PasswordSchemes).

## Logging In
IMAP and SMTP are configured to use STARTTLS on the normal client ports (143 for IMAP, 587 for SMTP). SSL-only ports (993 for IMAP, 465 for SMTP) are also available.

When configuring account settings, by default most mail clients will use only the local part (***user***@domain.com) for IMAP and SMTP logins. This works properly for local mail account delivery, but not for virtual domain accounts. Virtual account users must configure their mail client to use their full email address (user@domain.com) as the login username.

You can check what is being sent as the username for failed logins by looking in `/var/log/mail.log`:

    Nov 15 12:00:00 mail-server dovecot: imap-login: Aborted login (auth failed, 1 attempts in 5 secs): user=<localpartonly>, method=PLAIN, rip=192.168.1.100, lip=192.168.1.1, TLS: Disconnected, session=<RaNdOmSeSsIoNkEy>

If `localpartonly` is a user in a virtual mail domain, then (assuming their password is correct) that user can likely fix their logins by updating their client settings to use their full email address (i.e., `localpartonly@virtualdomain.com`) as their IMAP/SMTP username instead.

## Disclaimer
This is a release of Puppet configuration code that I've successfully used in production, but there is, as always, a chance that there are bugs or missing features. You should carefully examine the source as provided before using it on your own servers. If you find a bug or have a killer feature idea, please submit it to the project's GitHub Issues tracker.

## LICENSE

    Copyright 2013 Jacob Okamoto

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
