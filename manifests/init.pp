class varnish {
    package { curl:
        ensure => installed,
        before => Exec["add_varnish_key"],
            }
    exec { "add_varnish_key":
        command => "curl http://repo.varnish-cache.org/debian/GPG-key.txt | sudo apt-key add -",
        before  => Exec['apt_update'],
        require => Package['curl'],
        path    => '/usr/bin',
    }
    file { 'apt/sources.list':
        path    => '/etc/apt/sources.list.d/varnish.list',
        ensure  => file,
        before  => Exec['apt_update'],
        source => "puppet:///modules/varnish/sources.list",
    }
    exec { "apt_update":
        command => "sudo apt-get update",
        before  => Package['varnish'],
        path    => '/usr/bin',
    }
    package { varnish:
        ensure  => latest,
        require => Exec["apt_update"],
    }

    file { 'texastribune.org.vcl':
        path    => '/etc/varnish/texastribune.org.vcl',
        ensure  => file,
        require => Package['varnish'],
        before  => Service['varnish'],
        content => template("varnish/texastribune.org.vcl"),
    }
    file { 'secret':
        path    => '/etc/varnish/secret',
        ensure  => file,
        require => Package['varnish'],
        before  => Service['varnish'],
        source => "puppet:///modules/varnish/secret",
    }
    file { 'defaults':
        path    => '/etc/default/varnish',
        ensure  => file,
        require => Package['varnish'],
        before  => Service['varnish'],
        content => template("varnish/defaults"),
    }
    service { varnish:
        ensure     => running,
        enable     => true,
        hasrestart => true,
    }
}

include varnish
