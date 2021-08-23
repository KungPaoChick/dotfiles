#!/bin/env bash
set -e

# copies pacman.conf and mkinitcpio.conf
sudo cp -f systemfiles/pacman.conf \
           systemfiles/mkinitcpio.conf /etc/

# Adds pw_feedback to sudoers.d
sudo cp -f systemfiles/01_pw_feedback /etc/sudoers.d/

reset
echo 'm     m mmmmmm m        mmm   mmmm  m    m mmmmmm'; sleep 0.2
echo '#  #  # #      #      m"   " m"  "m ##  ## #'; sleep 0.2
echo '" #"# # #mmmmm #      #      #    # # ## # #mmmmm'; sleep 0.2
echo ' ## ##" #      #      #      #    # # "" # #'; sleep 0.2
echo ' #   #  #mmmmm #mmmmm  "mmm"  #mm#  #    # #mmmmm'; sleep 3

#
# choose video driver
#
echo "####################################################################

1.) xf86-video-intel    2.) xf86-video-amdgpu   3.) nvidia  4.) Skip

####################################################################"
read -r -p "Choose your video card driver. (Default: 1): " vidri

#
# prompt for installing recommended packages
#
cat recommended_packages.txt
read -p "Would you like to download these recommended system packages? [y/N] " recp

#
# select an aur helper to install
#
HELPER="yay"
mkdir -p $HOME/.srcs

echo "####################

1.) yay     2.) paru

####################"
printf  "\n\nAn AUR helper is essential to install required packages."
read -r -p "Select an AUR helper (Default: yay) " sel

#
# select a picom or picom fork
#
echo "##################################

1.) picom   2.) picom-jonaburg-git

##################################"
read -r -p "Select your preferred compositor. (Default: 1): " comp

#
# prompt for installing recommended aur packages
#
cat recommended_aur.txt
read -p "Would you like to download these recommended aur packages? [y/N] " reca

# prompt to install networking tools and applications
read -p "Would you like to install networking tools and applications? [y/N] " netw

# prompt to install audio tools and applications
read -p "Would you like to install audio tools and applications? [y/N] " aud

#
#
# post prompt process
#
#
case $vidri in
[1])
        DRIVER='xf86-video-intel xf86-video-nouveau'
        ;;

[2])
        DRIVER='xf86-video-amdgpu xf86-video-ati xf86-video-fbdev' 
        ;;

[3])
        DRIVER='nvidia nvidia-settings nvidia-utils'
        ;;

[4])
        DRIVER="xorg-xinit"
        ;;

*)
        DRIVER='xf86-video-intel xf86-video-nouveau'
        ;;
esac

# full upgrade
clear
printf "\n\nPerforming Upgrade and Installation Process...\n"
sudo pacman -Syy; sudo pacman -Syu --noconfirm

# installing selected video driver
sudo pacman -Sy --needed --noconfirm $DRIVER

# install system packages
sudo pacman -Sy --needed --noconfirm - < packages.txt

# recommended packages installer
if [[ "$recp" == "" || "$recp" == "N" || "$recp" == "n" ]]; then
    printf "\nAbort!\n"
    echo "You can install them later by doing: (sudo pacman -S - < recommended_packages.txt)"
else
    sudo pacman -Sy --needed --noconfirm - < recommended_packages.txt
fi

# aur installer
if [ $sel -eq 2 ]; then
    HELPER="paru"
fi

if ! command -v $HELPER &> /dev/null; then
    printf "\n\nWe'll be installing $HELPER then.\n\n"
        git clone https://aur.archlinux.org/$HELPER.git $HOME/.srcs/$HELPER
        (cd $HOME/.srcs/$HELPER/; makepkg -si --noconfirm)
fi

# install aur packages
$HELPER -Sy --needed --noconfirm - < aur.txt

# install selected compositor
case $comp in
[1])
        sudo pacman -S --needed --noconfirm picom &&
        cp -r compositors/picom-default/ $HOME/.config/picom
        ;;
[2])
        $HELPER -S --needed --noconfirm picom-jonaburg-git &&
        cp -r compositors/picom-jonaburg/ $HOME/.config/picom
        ;;
*)
        sudo pacman -S --needed --noconfirm picom &&
        cp -r compositors/picom-default/ $HOME/.config/picom
        ;;
esac

# recommended aur packages installer
if [[ "$reca" == "" || "$reca" == "N" || "$reca" == "n" ]]; then
    printf "\nAbort!\n"
    echo "You can install them later by doing: ($HELPER -S - < recommended_aur.txt)"
else
    $HELPER -Sy --needed --noconfirm - < recommended_aur.txt
fi

# enable services
sudo systemctl enable lxdm-plymouth.service

# touchpad configuration
sudo cp -f systemfiles/02-touchpad-ttc.conf /etc/X11/xorg.conf.d/

# scripts
sudo cp -f scripts/* /usr/local/bin/

# copy wallpapers to /usr/share/backgrounds/
sudo mkdir -p /usr/share/backgrounds/
sudo cp -rf wallpapers /usr/share/backgrounds/

# writes grub menu entries, copies grub, themes and updates it
sudo bash -c "cat >> '/etc/grub.d/40_custom' <<-EOF

menuentry 'Reboot System' --class restart {
    reboot
}

menuentry 'Shutdown System' --class shutdown {
    halt
}

EOF"
sudo cp -f grubcfg/grubd/* /etc/grub.d/
sudo cp -f grubcfg/grub /etc/default/
sudo cp -rf grubcfg/themes/default /boot/grub/themes/
sudo grub-mkconfig -o /boot/grub/grub.cfg

# plymouth
sudo cp -f lxdm/lxdm.conf /etc/lxdm/
sudo cp -rf lxdm/lxdm-theme/* /usr/share/lxdm/themes/
sudo plymouth-set-default-theme -R arch10

# make user dirs
xdg-user-dirs-update

# networking tools and applications installer
if [[ "$netw" == "" || "$netw" == "N" || "$netw" == "n" ]]; then
    printf "\nAbort!\n"
    echo "You can find the networking setup script in the bin folder."
else
     (cd bin/; ./networking_setup.sh)
fi

# audio tools and applications installer
if [[ "$aud" == "" || "$aud" == "N" || "$aud" == "n" ]]; then
    printf "\nAbort!\n"
    echo "You can find the audio setup script in the bin folder."
else
    (cd bin/; ./audio_setup.sh)
fi

# installs oh-my-zsh and changes shell to zsh
curl -L http://install.ohmyz.sh | sh
sudo chsh -s /bin/zsh; chsh -s /bin/zsh

# copy home dots
cp -rf dots/.zshrc    \
       dots/.vimrc    \
       dots/.xinitrc  \
       dots/.hushlogin\
       dots/.gtkrc-2.0\
       dots/.gitconfig\
       dots/.fehbg    \
       dots/.dmrc     \
       dots/.ncmpcpp/ \
       dots/.mpd/ $HOME
       
cp -rf configs/* $HOME/.config/

# copy songs
cp songs/* $HOME/Music

# install fonts for polybar
FDIR="$HOME/.local/share/fonts"
echo -e "\n[*] Installing fonts..."
if [[ -d "$FDIR" ]]; then
    cp -rf fonts/* "$FDIR"
else
    mkdir -p "$FDIR"
    cp -rf fonts/* "$FDIR"
fi

# clone zsh plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# last orphan delete and cache delete
sudo pacman -Rns --noconfirm $(pacman -Qtdq); sudo pacman -Sc --noconfirm; $HELPER -Sc --noconfirm; sudo pacman -R --noconfirm i3-wm

# final
rm -rf $HOME/.srcs/$HELPER
clear

read -p "$USER!, Reboot Now? (Required) [Y/n] " reb
if [[ "$reb" == "" || "$reb" == "Y" || "$reb" == "y" ]]; then
    sudo reboot now
else
    printf "\nAbort!\n"
fi
