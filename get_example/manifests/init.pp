class get_example {

    # looks up data in var_dev/main.yml
    $user = get_var("get_example", "username")

    # looks up data in secret_dev/main.yml
    $password = get_secret("get_example", "$user.password")

    # looks up data in secret_dev/keys.yml
    $private_key = get_secret("get_example", "keys:ssh.private")

    file { "/tmp/config.yml":
        content => template("get_example/config.yml.erb")
    }

    file { "/tmp/private_key":
        content => $private_key
    }

    define write_host () {
        # looks up in secret_dev/hosts.yml, and doesn't fail if value isn't found
        # just returns the default
        $pass = get_secret("get_example", "hosts:$name", "defaultpass")

        # looks up in var_dev/hosts.yml
        $ip = get_var("get_example", "hosts:$name.ip")

        file { "/tmp/host_$name":
            content => template("get_example/host.erb")
        }
    }

    # gets keys of top level hash in the var_dev/hosts.yml file
    $hosts = get_var("get_example", "hosts:keys")

    write_host {$hosts: }
}
