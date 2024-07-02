packer {
  required_plugins {
    arm-image = {
      version = "0.2.5"
      source  = "github.com/solo-io/arm-image"
    }
  }
}

variable "build" {
  type    = string
  default = "stable"
}
variable "pibranch" {
  type    = string
  default = "main"
}

variable "url" {
  type    = string
  default = ""
}

source "arm-image" "companion" {
  iso_checksum              = "none"
  iso_url                   = var.url
  target_image_size         = 5000000000
  output_filename           = "output-companion/armbian-companion.img"
  qemu_binary               = "qemu-aarch64-static"
  image_mounts              = ["/"]
}

build {
  sources = ["source.arm-image.companion"]

  provisioner "file" {
    source = "companion-pi/install.sh"
    destination = "/tmp/install.sh"
  }

  provisioner "shell" {
    #system setup
    inline = [
      # enable ssh
      # "touch /boot/ssh",

      # change the hostname
      "CURRENT_HOSTNAME=`cat /etc/hostname | tr -d \" \t\n\r\"`",
      "echo companion > /etc/hostname",
      "sed -i \"s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\tcompanion/g\" /etc/hosts",

      # install some dependencies
      "apt-get update -yq",
      "apt-mark hold openssh-server armbian-bsp-cli-orangepizero2 armbian-config armbian-firmware armbian-zsh",
      "apt-get upgrade -yq --option=Dpkg::Options::=--force-confdef",
      "apt-get install -o Dpkg::Options::=\"--force-confold\" -yqq git unzip curl pkg-config make gcc g++ libusb-1.0-0-dev libudev-dev cmake",
      "apt-get clean",
    ]
  }

  provisioner "shell" {
    # run as root
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} su root -c {{ .Path }}"
    inline_shebang  = "/bin/bash -e"
    inline = [
      # run the script
      "export COMPANIONPI_BRANCH=${var.pibranch}",
      "export COMPANION_BUILD=${var.build}",
      "chmod +x /tmp/install.sh",
      "/tmp/install.sh"
    ]
  }

}
