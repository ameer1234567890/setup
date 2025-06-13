These are sets of setup instrutions for some of my devices

## Currently supported devices
* MikroTik hAP Mini (Tomato)
* MikroTik hAP Mini (Potato)
* Raspberry Pi 1 (nas1)
* Raspberry Pi 3B+ (nas2)
* Asus X541NA (fig)
* OnePlus Nord CE 5G (apricot)
* Orange Pi Zero 2 (printer)
* Asus X553SA (ameerpc2)
* Backup Phone

## Backup State
| Service | Location | Software | Frequency |
|---------|----------|----------|-----------|
| Google Drive | NAS1 - USB1 | rclone | Auto |
| Google Keep | NAS1 - USB1 | Google Takeout | Auto (via exports to Google Drive) |
| Google Calendar | NAS1 - USB1 | Google Takeout | Auto (via exports to Google Drive) |
| Google Contacts | NAS1 - USB1 | Google Takeout | Auto (via exports to Google Drive) |
| Chrome Bookmarks | NAS1 - USB1 | Google Takeout | Auto (via exports to Google Drive) |
| Google Photos | NAS1 - USB1 | rclone | Auto |
| Gmail | FIG - HDD1 | Thunderbird | Auto |
| Ameer Laptop | NAS1 - USB1 | rsync | Auto |
| Aani Laptop | NAS1 - USB1 | rsync | Auto |
| Ameer Phone | NAS1 - USB1 | rsync | Auto |
| Aani Phone | NAS1 - USB1 | rsync | Auto |
| Nimra Laptop | NAS1 - USB1 | rsync | Auto |
| Nimra Tablet | NAS1 - USB1 | rsync | Auto |
| Movies | NAS2 - USB5 & USB6 | rsync | Auto |
| Nimra TV Videos | NAS1 - USB6 | rsync | Manual |
| Offsite Backup | Aani College Google Drive | rclone | Auto |

## Drive Inventory
| Drive | Location | HDD/SSD | Size | Backup Location | Use |
|---------|----------|----------|-----------|-----------|-----------|
| USB1 | NAS1 | SSD | 1TB | USB6 | Storage of backup from laptops, phones, google accounts, github, etc... |
| USB2 | NAS2 | SSD | 1TB | Offsite (GDrive) | Movies |
| USB3 | NAS2 | SSD | 500GB | USB5 | Data drive, Audiobooks, Ebooks & Movies |
| USB4 | NAS2 | SSD | 1TB | Offsite (GDrive) | Movies |
| USB5 | NAS2 | HDD | 500GB | Offsite (GDrive) | Backup of USB3 |
| USB6 | NAS2 | HDD | 500GB | Offsite (GDrive) | Backup of USB1, USB8, HDD1 & MMC1 |
| USB8 | Printer | SSD | 125GB | USB6 | Data drive |
| HDD1 | FIG | HDD | 500GB | USB6 | Data drive |
| MMC1 | APRICOT | SSD | 64GB | USB6 | Data drive |
