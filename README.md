## Welcome to the ESXi-Customizer-PS GitHub Pages

Full documentation is currently available at the [V-Front.de web site](https://esxi-customizer-ps.v-front.de) and will be gradually migrated to this location.

## Run inside a container

For users who don't want to install or are not familiar with `powershell`, in this example, we will use `Docker` as our container engine.

1. Build the image

    ```bash
    # build and tag a new image using `./Dockerfile`
    $ docker build -t esxi-customizer-ps .
    ```

2. Run (in this example, we make an alias to shorten the commandline)

    ```bash
    $ alias esxi-cps='docker run -it -v $(pwd):/data --rm esxi-customizer-ps'

    # esxi-cps [options]
    $ esxi-cps --help
    ```
