packer {
  required_plugins {
    arm-image = {
      version = "0.2.5"
      source  = "github.com/solo-io/arm-image"
    }
  }
}

variable "branch" {
  type    = string
  default = "beta"
}
variable "pibranch" {
  type    = string
  default = "main"
}

variable "url" {
  type    = string
  default = "http://xogium.performanceservers.nl/archive/orangepizero2/archive/Armbian_22.11.3_Orangepizero2_jammy_edge_6.1.4_minimal.img.xz"
}

source "arm-image" "companion" {
  iso_checksum              = "sha256:3cd9574a6e7facd6fc37665a701dc079d0f05ed2ad22e6d0ed8919c224a7e00f"
  iso_url                   = var.url
  target_image_size         = 4000000000
  output_filename           = "output-companion/armbian-companion.img"
  qemu_binary               = "qemu-aarch64-static"
  image_mounts              = ["/"]
}

build {
  sources = ["source.arm-image.companion"]

  provisioner "shell" {
    #system setup
    inline = [
      # enable ssh
      # "touch /boot/ssh",

      # change the hostname
      "CURRENT_HOSTNAME=`cat /etc/hostname | tr -d \" \t\n\r\"`",
      "echo companion > /etc/hostname",
      "sed -i \"s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\tcompanion/g\" /etc/hosts",

      # add a system user
      "adduser --disabled-password companion --gecos \"\"",

      # install some dependencies
      "apt-get update",
      "apt-get install -o Dpkg::Options::=\"--force-confold\" -yqq git unzip curl pkg-config make gcc g++ libusb-1.0-0-dev libudev-dev cmake",
      "apt-get clean",
    ]
  }

  provisioner "shell" {
    # run as root
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} su root -c {{ .Path }}"
    inline_shebang  = "/bin/bash -e"
    inline = [
      # install fnm to manage node version
      # we do this to /opt/fnm, so that the companion user can use the same installation
      "export FNM_DIR=/opt/fnm",
      "echo \"export FNM_DIR=/opt/fnm\" >> /root/.bashrc",
      "curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir /opt/fnm",
      "export PATH=/opt/fnm:$PATH",
      "eval \"`fnm env --shell bash`\"",

      # clone the companionpi repository
      "git clone https://github.com/bitfocus/companion-pi.git -b ${var.pibranch} /usr/local/src/companionpi",
      "cd /usr/local/src/companionpi",

      # configure git for future updates
      "git config --global pull.rebase false",

      # run the update script
      "./update.sh ${var.branch}",

      # install update script dependencies, as they were ignored
      "yarn --cwd \"/usr/local/src/companionpi/update-prompt\" install",

      # enable start on boot
      "systemctl enable companion"
    ]
  }

  provisioner "shell" {
    # run as companion user
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} su companion -c {{ .Path }}"
    inline_shebang  = "/bin/bash -e"
    inline = [
      # "cd /usr/local/src/companion",

      # add the fnm node to this users path
      "echo \"export PATH=/opt/fnm/aliases/default/bin:\\$PATH\" >> ~/.bashrc"

    ]
  }

}