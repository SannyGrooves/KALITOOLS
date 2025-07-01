# KALI TOOLS
KALI TOOLS FOR MAC

<img width="426" alt="Scherm­afbeelding 2025-07-01 om 11 52 25" src="https://github.com/user-attachments/assets/626192cd-dea1-44c3-b060-3e2c535dfe2e" />

INSTALL DIR = USER/DOCUMENTS/KALI_TOOLS

Requirements:
Homebrew,paste this command in terminal:
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install python3
/usr/local/bin/pip3 install --upgrade pip
/usr/local/bin/pip3 install virtualenv
sudo /usr/local/bin/pip3 install virtualenv


HOW TO USE
COPY PATH OF FOLDER kalitools-main
START TERMINAL
TYPE

	cd /<insert copied path here>

4. Run the Installation Script. 
This installs tools, sets up the virtual environment ($HOME/kalitools-main_venv), and creates the kalitools command:

		chmod +x install.sh ./install.sh


6. program will make virtual python evn and start the program

Run:

	sudo kali_tools


RUN THE MENU:

	sudo kali_tools


SPECIAL CUSTOM TOOL:

	Generate the Detailed Report (combining the most powerfull tools of kli together):
	Select option 17 ("Generate Detailed Report - WHOIS, Geolocation, Subdomains").
	Enter a domain (e.g., example.com).
	Specify a filepath (e.g., $HOME/kali_tools/export_info.html) or press Enter for a default    path ($HOME/kali_tools/export_info_YYYYMMDD_HHMMSS.html).
	Make sure you add .html at end of file name while exporting
The report will be saved with fancy.css styling, and fancy.css will be saved to your kalitools-main folder

problem solvers:
Test Virtual Environment Creation
If virtualenv installs successfully, test creating a virtual environment:
/usr/local/bin/virtualenv test_venv
source test_venv/bin/activate
python --version
deactivate
rm -rf test_venv

========================================
Constraints:

    The directory must be writable by the user (e.g., avoid /System or root-owned paths).
    Default to $HOME/kali_tools if the user doesn’t specify a path or if the chosen path is invalid.
    Ensure the kali_tools command works system-wide (via /usr/local/bin/kali_tools).
    Maintain the advanced report functionality (running whois, dig, nslookup, sublist3r, amass, dnsrecon, nmap, fping for domain/IP inputs).
    Ensure fancy.css is correctly linked in HTML reports regardless of the directory.
