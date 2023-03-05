# CCryptor.nvim
A Neovim **Linux** plugin to easy encrypt and decrypt your secured directory, based on ccrypt 


![output](https://user-images.githubusercontent.com/20345096/200641339-0b58cfcd-5152-4295-a72f-250c22af981b.gif)

## Disclaimer
The plugin is tested with `ccrypt 1.11 version`  
I used it already for several months as a password manager without major issues.  
But still be careful, **you can lose your data** always make a backup.  

## How it works

All files into `dir_pattern` and its subfolders will be encrypted by [ccrypt](https://ccrypt.sourceforge.net/) after first write operation by password.  
You must use **the same password** for whole `dir_pattern` directory.  
*Decrypted text keeps only in Neovim buffer*

## Install and setup
### Prerequisites
- Installed [ccrypt](https://ccrypt.sourceforge.net/) utility
```bash
sudo apt install ccrypt
```
- [find](https://www.gnu.org/software/findutils/) - Usually it is automatically installed with your Linux distro

### Install the plugin
```vim
Plug 'kurotych/ccryptor.nvim'
```
### Configure
```vim
lua <<EOF
require("ccryptor").setup({
    dir_path = '/home/kurotych/secrets/'
})
EOF
```
| setting | description | example |
| --- | --- | --- |
| dir_path | directory path that will be ecnrypted (with its subfolders) | /home/kurotych/secrets/ |
