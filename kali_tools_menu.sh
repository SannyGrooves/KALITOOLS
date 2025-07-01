#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Directories
LOG_DIR="$HOME/kali_tools/logs"
CSS_DIR="$HOME/kali_tools/css"
mkdir -p "$LOG_DIR" "$CSS_DIR"
LOG_FILE="$LOG_DIR/kali_tools_$(date +%Y%m%d_%H%M%S).log"
VENV_DIR="$HOME/kali_tools_venv"

# Function to log messages
log_message() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') $message" >> "$LOG_FILE"
}

# Function to check if a tool is available
check_tool() {
    local tool=$1
    if [ "$tool" == "netcat" ]; then
        tool="nc"
    fi
    if [ "$tool" == "sublist3r" ] || [ "$tool" == "dnsrecon" ] || [ "$tool" == "mitmproxy" ]; then
        command -v "$VENV_DIR/bin/$tool" &> /dev/null
    else
        command -v "$tool" &> /dev/null
    fi
    return $?
}

# Function to validate domain or IP
validate_input() {
    local input=$1
    if [[ $input =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "ip"
    elif [[ $input =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "domain"
    else
        echo "invalid"
    fi
}

# Function to get geolocation data for an IP
get_geolocation() {
    local ip=$1
    local output_file=$(mktemp)
    "$VENV_DIR/bin/python" - <<EOF > "$output_file" 2>> "$LOG_FILE"
import requests
import json

ip = "$ip"
try:
    response = requests.get(f"http://ip-api.com/json/{ip}", timeout=5)
    if response.status_code == 200:
        data = response.json()
        if data.get("status") == "success":
            result = {
                "ip": ip,
                "country": data.get("country", "N/A"),
                "city": data.get("city", "N/A"),
                "isp": data.get("isp", "N/A"),
                "org": data.get("org", "N/A"),
                "lat": data.get("lat", "N/A"),
                "lon": data.get("lon", "N/A"),
                "timezone": data.get("timezone", "N/A")
            }
            print(json.dumps(result))
        else:
            print(json.dumps({"ip": ip, "error": "Geolocation failed"}))
    else:
        print(json.dumps({"ip": ip, "error": f"HTTP {response.status_code}"}))
except Exception as e:
    print(json.dumps({"ip": ip, "error": str(e)}))
EOF
    cat "$output_file"
    rm -f "$output_file"
}

# Function to generate detailed HTML report
generate_html_report() {
    local input=$1
    local input_type=$2
    local filepath=$3
    local whois_output=""
    local dig_output=""
    local nslookup_output=""
    local sublist3r_output=""
    local amass_output=""
    local dnsrecon_output=""
    local nmap_output=""
    local fping_output=""
    local geo_data=()

    # Run tools based on input type
    if [ "$input_type" == "domain" ]; then
        # whois
        log_message "Running whois for $input"
        if check_tool "whois"; then
            whois_output=$(whois "$input" 2>> "$LOG_FILE")
            if [ $? -ne 0 ]; then
                whois_output="Error: Failed to run whois"
                log_message "Error running whois for $input"
            fi
        else
            whois_output="Error: whois not found"
            log_message "Error: whois not found"
        fi

        # dig
        log_message "Running dig for $input"
        if check_tool "dig"; then
            dig_output=$(dig "$input" 2>> "$LOG_FILE")
            if [ $? -ne 0 ]; then
                dig_output="Error: Failed to run dig"
                log_message "Error running dig for $input"
            fi
        else
            dig_output="Error: dig not found"
            log_message "Error: dig not found"
        fi

        # sublist3r
        log_message "Running sublist3r for $input"
        if check_tool "sublist3r"; then
            sublist3r_output=$("$VENV_DIR/bin/sublist3r" -d "$input" 2>> "$LOG_FILE")
            if [ $? -ne 0 ]; then
                sublist3r_output="Error: Failed to run sublist3r"
                log_message "Error running sublist3r for $input"
            fi
        else
            sublist3r_output="Error: sublist3r not found"
            log_message "Error: sublist3r not found"
        fi

        # amass
        log_message "Running amass for $input"
        if check_tool "amass"; then
            amass_output=$(amass enum -d "$input" -timeout 300 2>> "$LOG_FILE")
            if [ $? -ne 0 ]; then
                amass_output="Error: Failed to run amass"
                log_message "Error running amass for $input"
            fi
        else
            amass_output="Error: amass not found"
            log_message "Error: amass not found"
        fi

        # dnsrecon
        log_message "Running dnsrecon for $input"
        if check_tool "dnsrecon"; then
            dnsrecon_output=$("$VENV_DIR/bin/dnsrecon" -d "$input" 2>> "$LOG_FILE")
            if [ $? -ne 0 ]; then
                dnsrecon_output="Error: Failed to run dnsrecon"
                log_message "Error running dnsrecon for $input"
            fi
        else
            dnsrecon_output="Error: dnsrecon not found"
            log_message "Error: dnsrecon not found"
        fi
    fi

    # nslookup (domain or IP)
    log_message "Running nslookup for $input"
    if check_tool "nslookup"; then
        nslookup_output=$(nslookup "$input" 2>> "$LOG_FILE")
        if [ $? -ne 0 ]; then
            nslookup_output="Error: Failed to run nslookup"
            log_message "Error running nslookup for $input"
        fi
    else
        nslookup_output="Error: nslookup not found"
        log_message "Error: nslookup not found"
    fi

    # nmap (domain or IP)
    log_message "Running nmap for $input"
    if check_tool "nmap"; then
        nmap_output=$(nmap -Pn -sS -F "$input" 2>> "$LOG_FILE")
        if [ $? -ne 0 ]; then
            nmap_output="Error: Failed to run nmap"
            log_message "Error running nmap for $input"
        fi
    else
        nmap_output="Error: nmap not found"
        log_message "Error: nmap not found"
    fi

    # fping (IP only)
    if [ "$input_type" == "ip" ]; then
        log_message "Running fping for $input"
        if check_tool "fping"; then
            fping_output=$(fping -a "$input" 2>> "$LOG_FILE")
            if [ $? -ne 0 ]; then
                fping_output="Error: Failed to run fping"
                log_message "Error running fping for $input"
            fi
        else
            fping_output="Error: fping not found"
            log_message "Error: fping not found"
        fi
    else
        fping_output="N/A: fping is IP-only"
        log_message "Skipping fping for domain input $input"
    fi

    # Get IPs for geolocation (from dig or nslookup for domains, direct input for IPs)
    local ips=()
    if [ "$input_type" == "ip" ]; then
        ips=("$input")
    elif [ "$input_type" == "domain" ] && [ -n "$dig_output" ] && [[ "$dig_output" != *"Error"* ]]; then
        while IFS= read -r line; do
            if [[ $line =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                ips+=("$line")
            fi
        done <<< "$(echo "$dig_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')"
    fi
    for ip in "${ips[@]}"; do
        geo_data+=("$(get_geolocation "$ip")")
    done

    # Parse whois output
    whois_data=""
    if [ "$input_type" == "domain" ] && [[ "$whois_output" != *"Error"* ]]; then
        registrar=$(echo "$whois_output" | grep -i "Registrar:" | head -n1 | awk -F": " '{print $2}' | tr -d '\n')
        reg_date=$(echo "$whois_output" | grep -i "Creation Date:" | head -n1 | awk -F": " '{print $2}' | tr -d '\n')
        exp_date=$(echo "$whois_output" | grep -i "Expiry Date:" | head -n1 | awk -F": " '{print $2}' | tr -d '\n')
        name_servers=$(echo "$whois_output" | grep -i "Name Server:" | awk -F": " '{print $2}' | tr '\n' ', ' | sed 's/, $//')
        whois_data="{\"registrar\": \"$registrar\", \"creation_date\": \"$reg_date\", \"expiry_date\": \"$exp_date\", \"name_servers\": \"$name_servers\"}"
    else
        whois_data="{\"error\": \"$whois_output\"}"
    fi

    # Parse subdomains from sublist3r and amass
    subdomains=()
    if [ "$input_type" == "domain" ]; then
        if [[ "$sublist3r_output" != *"Error"* ]]; then
            while IFS= read -r line; do
                if [[ $line =~ ^[a-zA-Z0-9.-]+\.$input$ ]]; then
                    subdomains+=("$line")
                fi
            done <<< "$sublist3r_output"
        fi
        if [[ "$amass_output" != *"Error"* ]]; then
            while IFS= read -r line; do
                if [[ $line =~ ^[a-zA-Z0-9.-]+\.$input$ ]]; then
                    subdomains+=("$line")
                fi
            done <<< "$amass_output"
        fi
        subdomains=($(echo "${subdomains[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    fi

    # Parse DNS records from dig
    dns_records=()
    if [ "$input_type" == "domain" ] && [[ "$dig_output" != *"Error"* ]]; then
        while IFS= read -r line; do
            if [[ $line =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}[[:space:]]+[0-9]+[[:space:]]+(IN|A|NS|MX|CNAME|TXT)[[:space:]]+ ]]; then
                record_type=$(echo "$line" | awk '{print $4}')
                record_value=$(echo "$line" | awk '{print $5}')
                dns_records+=("{\"type\": \"$record_type\", \"value\": \"$record_value\"}")
            fi
        done <<< "$dig_output"
    fi

    # Parse nmap ports
    nmap_ports=()
    if [[ "$nmap_output" != *"Error"* ]]; then
        while IFS= read -r line; do
            if [[ $line =~ ^[0-9]+/(tcp|udp)[[:space:]]+(open|filtered)[[:space:]]+[a-zA-Z0-9-]+ ]]; then
                port=$(echo "$line" | awk '{print $1}')
                state=$(echo "$line" | awk '{print $2}')
                service=$(echo "$line" | awk '{print $3}')
                nmap_ports+=("{\"port\": \"$port\", \"state\": \"$state\", \"service\": \"$service\"}")
            fi
        done <<< "$nmap_output"
    fi

    # Save fancy.css
    cat > "$CSS_DIR/fancy.css" << 'CSS_EOF'
/* Fancy CSS for Kali Tools Domain Report */

/* Reset and base styles */
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: linear-gradient(135deg, #1e3a8a 0%, #3b82f6 50%, #60a5fa 100%);
    color: #ffffff;
    line-height: 1.6;
    min-height: 100vh;
    padding: 1rem;
}

/* Container */
.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 2rem;
}

/* Header */
h1 {
    font-size: 2.5rem;
    font-weight: 700;
    text-align: center;
    margin-bottom: 1rem;
    text-shadow: 0 2px 4px rgba(0, 0, 0, 0.3);
    animation: fadeIn 1s ease-in-out;
}

p.text-center {
    text-align: center;
    font-size: 1.1rem;
    margin-bottom: 2rem;
    opacity: 0.9;
}

/* Section containers */
.section {
    background: rgba(255, 255, 255, 0.1);
    backdrop-filter: blur(10px);
    border-radius: 1rem;
    padding: 2rem;
    margin-bottom: 2rem;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
    border: 1px solid rgba(255, 255, 255, 0.2);
    transition: transform 0.3s ease, box-shadow 0.3s ease;
}

.section:hover {
    transform: translateY(-5px);
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.3);
}

h2 {
    font-size: 1.8rem;
    font-weight: 600;
    color: #ffffff;
    margin-bottom: 1.5rem;
    border-bottom: 2px solid #3b82f6;
    padding-bottom: 0.5rem;
}

/* Tables */
table {
    width: 100%;
    border-collapse: separate;
    border-spacing: 0;
    background: rgba(255, 255, 255, 0.95);
    color: #1f2937;
    border-radius: 0.5rem;
    overflow: hidden;
}

th, td {
    padding: 0.75rem;
    text-align: left;
    border-bottom: 1px solid rgba(0, 0, 0, 0.1);
}

th {
    background: #3b82f6;
    color: #ffffff;
    font-weight: 600;
}

tr:nth-child(even) {
    background: rgba(0, 0, 0, 0.05);
}

tr:hover {
    background: rgba(59, 130, 246, 0.1);
    transition: background 0.2s ease;
}

td[colspan] {
    text-align: center;
    font-style: italic;
    color: #6b7280;
}

/* Collapsible details */
details {
    margin-top: 1rem;
}

summary {
    cursor: pointer;
    font-weight: 600;
    color: #3b82f6;
    padding: 0.5rem;
    background: rgba(255, 255, 255, 0.1);
    border-radius: 0.5rem;
    transition: background 0.3s ease;
}

summary:hover {
    background: rgba(255, 255, 255, 0.2);
}

pre {
    background: #1f2937;
    color: #e5e7eb;
    padding: 1rem;
    border-radius: 0.5rem;
    overflow-x: auto;
    font-size: 0.9rem;
    margin-top: 0.5rem;
}

code {
    font-family: 'Fira Code', monospace;
}

/* Animations */
@keyframes fadeIn {
    from { opacity: 0; transform: translateY(-20px); }
    to { opacity: 1; transform: translateY(0); }
}

.section {
    animation: fadeIn 0.5s ease-in-out;
}

/* Responsive design */
@media (max-width: 768px) {
    .container {
        padding: 1rem;
    }

    h1 {
        font-size: 1.8rem;
    }

    h2 {
        font-size: 1.5rem;
    }

    table {
        font-size: 0.9rem;
    }

    th, td {
        padding: 0.5rem;
    }

    pre {
        font-size: 0.8rem;
    }
}

@media (max-width: 480px) {
    h1 {
        font-size: 1.5rem;
    }

    h2 {
        font-size: 1.2rem;
    }

    table {
        display: block;
        overflow-x: auto;
    }
}
CSS_EOF
    chmod 644 "$CSS_DIR/fancy.css"
    log_message "Saved fancy.css to $CSS_DIR/fancy.css"

    # Generate HTML
    cat > "$filepath" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kali Tools ${input_type^} Report - $input</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/default.min.css" rel="stylesheet">
    <link href="css/fancy.css" rel="stylesheet">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
</head>
<body>
    <div class="container">
        <h1>Kali Tools ${input_type^} Report: $input</h1>
        <p class="text-center">Generated on $(date '+%Y-%m-%d %H:%M:%S')</p>

        <div class="section">
            <h2>Geolocation Data</h2>
            <table>
                <thead>
                    <tr>
                        <th>IP</th>
                        <th>Country</th>
                        <th>City</th>
                        <th>ISP</th>
                        <th>Organization</th>
                        <th>Latitude</th>
                        <th>Longitude</th>
                        <th>Timezone</th>
                    </tr>
                </thead>
                <tbody>
EOF
    if [ ${#geo_data[@]} -eq 0 ]; then
        echo "                    <tr><td colspan='8'>No geolocation data available</td></tr>" >> "$filepath"
    else
        for geo in "${geo_data[@]}"; do
            ip=$(echo "$geo" | jq -r '.ip')
            country=$(echo "$geo" | jq -r '.country')
            city=$(echo "$geo" | jq -r '.city')
            isp=$(echo "$geo" | jq -r '.isp')
            org=$(echo "$geo" | jq -r '.org')
            lat=$(echo "$geo" | jq -r '.lat')
            lon=$(echo "$geo" | jq -r '.lon')
            timezone=$(echo "$geo" | jq -r '.timezone')
            if [[ "$geo" != *"error"* ]]; then
                echo "                    <tr><td>$ip</td><td>$country</td><td>$city</td><td>$isp</td><td>$org</td><td>$lat</td><td>$lon</td><td>$timezone</td></tr>" >> "$filepath"
            else
                error=$(echo "$geo" | jq -r '.error')
                echo "                    <tr><td>$ip</td><td colspan='7'>Error: $error</td></tr>" >> "$filepath"
            fi
        done
    fi
    cat >> "$filepath" << EOF
                </tbody>
            </table>
        </div>

        <div class="section">
            <h2>WHOIS Information</h2>
            <table>
                <thead>
                    <tr>
                        <th>Field</th>
                        <th>Value</th>
                    </tr>
                </thead>
                <tbody>
EOF
    if [ "$input_type" == "domain" ] && [[ "$whois_data" != *"error"* ]]; then
        echo "                    <tr><td>Registrar</td><td>$registrar</td></tr>" >> "$filepath"
        echo "                    <tr><td>Creation Date</td><td>$reg_date</td></tr>" >> "$filepath"
        echo "                    <tr><td>Expiry Date</td><td>$exp_date</td></tr>" >> "$filepath"
        echo "                    <tr><td>Name Servers</td><td>$name_servers</td></tr>" >> "$filepath"
    else
        echo "                    <tr><td>Error</td><td>${whois_output:-N/A: WHOIS is domain-only}</td></tr>" >> "$filepath"
    fi
    cat >> "$filepath" << EOF
                </tbody>
            </table>
            <details>
                <summary>Raw WHOIS Output</summary>
                <pre><code class="language-text">${whois_output:-N/A}</code></pre>
            </details>
        </div>

        <div class="section">
            <h2>DNS Records (dig)</h2>
            <table>
                <thead>
                    <tr>
                        <th>Type</th>
                        <th>Value</th>
                    </tr>
                </thead>
                <tbody>
EOF
    if [ "$input_type" == "domain" ] && [ ${#dns_records[@]} -gt 0 ]; then
        for record in "${dns_records[@]}"; do
            type=$(echo "$record" | jq -r '.type')
            value=$(echo "$record" | jq -r '.value')
            echo "                    <tr><td>$type</td><td>$value</td></tr>" >> "$filepath"
        done
    else
        echo "                    <tr><td colspan='2'>${dig_output:-N/A: dig is domain-only}</td></tr>" >> "$filepath"
    fi
    cat >> "$filepath" << EOF
                </tbody>
            </table>
            <details>
                <summary>Raw dig Output</summary>
                <pre><code class="language-text">${dig_output:-N/A}</code></pre>
            </details>
        </div>

        <div class="section">
            <h2>nslookup Results</h2>
            <table>
                <thead>
                    <tr>
                        <th>Output</th>
                    </tr>
                </thead>
                <tbody>
                    <tr><td>${nslookup_output:-No data available}</td></tr>
                </tbody>
            </table>
            <details>
                <summary>Raw nslookup Output</summary>
                <pre><code class="language-text">$nslookup_output</code></pre>
            </details>
        </div>

        <div class="section">
            <h2>Subdomains</h2>
            <table>
                <thead>
                    <tr>
                        <th>Subdomain</th>
                    </tr>
                </thead>
                <tbody>
EOF
    if [ "$input_type" == "domain" ] && [ ${#subdomains[@]} -gt 0 ]; then
        for subdomain in "${subdomains[@]}"; do
            echo "                    <tr><td>$subdomain</td></tr>" >> "$filepath"
        done
    else
        echo "                    <tr><td>${sublist3r_output:-N/A: Subdomains are domain-only}</td></tr>" >> "$filepath"
    fi
    cat >> "$filepath" << EOF
                </tbody>
            </table>
            <details>
                <summary>Raw sublist3r Output</summary>
                <pre><code class="language-text">${sublist3r_output:-N/A}</code></pre>
            </details>
            <details>
                <summary>Raw amass Output</summary>
                <pre><code class="language-text">${amass_output:-N/A}</code></pre>
            </details>
        </div>

        <div class="section">
            <h2>DNS Reconnaissance (dnsrecon)</h2>
            <table>
                <thead>
                    <tr>
                        <th>Output</th>
                    </tr>
                </thead>
                <tbody>
                    <tr><td>${dnsrecon_output:-N/A: dnsrecon is domain-only}</td></tr>
                </tbody>
            </table>
            <details>
                <summary>Raw dnsrecon Output</summary>
                <pre><code class="language-text">${dnsrecon_output:-N/A}</code></pre>
            </details>
        </div>

        <div class="section">
            <h2>Port Scan (nmap)</h2>
            <table>
                <thead>
                    <tr>
                        <th>Port</th>
                        <th>State</th>
                        <th>Service</th>
                    </tr>
                </thead>
                <tbody>
EOF
    if [ ${#nmap_ports[@]} -gt 0 ]; then
        for port in "${nmap_ports[@]}"; do
            port_num=$(echo "$port" | jq -r '.port')
            state=$(echo "$port" | jq -r '.state')
            service=$(echo "$port" | jq -r '.service')
            echo "                    <tr><td>$port_num</td><td>$state</td><td>$service</td></tr>" >> "$filepath"
        done
    else
        echo "                    <tr><td colspan='3'>${nmap_output:-No ports found}</td></tr>" >> "$filepath"
    fi
    cat >> "$filepath" << EOF
                </tbody>
            </table>
            <details>
                <summary>Raw nmap Output</summary>
                <pre><code class="language-text">$nmap_output</code></pre>
            </details>
        </div>

        <div class="section">
            <h2>Ping Sweep (fping)</h2>
            <table>
                <thead>
                    <tr>
                        <th>Output</th>
                    </tr>
                </thead>
                <tbody>
                    <tr><td>$fping_output</td></tr>
                </tbody>
            </table>
            <details>
                <summary>Raw fping Output</summary>
                <pre><code class="language-text">$fping_output</code></pre>
            </details>
        </div>

        <script>hljs.highlightAll();</script>
    </div>
</body>
</html>
EOF
    log_message "Generated HTML report at $filepath"
    echo -e "${GREEN}Report saved to: $filepath${NC}"
}

# Menu Loop
while true; do
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════╗"
    echo "║         🛠️  Kali Tools for macOS 🛠️        ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${YELLOW}Select a tool to run:${NC}"
    echo " 1) tshark           - Packet sniffer (requires sudo)"
    echo " 2) tcpdump          - CLI packet capture (requires sudo)"
    echo " 3) ngrep            - Pattern-based sniffer (requires sudo)"
    echo " 4) mitmproxy        - HTTPS MITM proxy"
    echo " 5) dnsrecon         - DNS reconnaissance"
    echo " 6) whois            - Domain WHOIS lookup"
    echo " 7) dig              - DNS query tool"
    echo " 8) nslookup         - DNS lookup tool"
    echo " 9) sublist3r        - Subdomain enumeration"
    echo "10) amass            - DNS mapping and enumeration"
    echo "11) nmap             - Network scanner"
    echo "12) fping            - Ping sweep tool"
    echo "13) bettercap        - MITM framework (requires sudo)"
    echo "14) netcat           - Raw networking (nc)"
    echo "15) socat           - Advanced networking tool"
    echo "16) tcpflow         - TCP forensics (requires sudo)"
    echo "17) Generate Advanced Report - All Domain/IP Tools"
    echo " 0) Exit"
    echo -ne "${GREEN}Enter your choice: ${NC}"
    read choice

    # Validate tool availability
    case $choice in
        1) TOOL="tshark"; CMD="sudo tshark -i en0 -c 10"; SUDO="yes" ;;
        2) TOOL="tcpdump"; CMD="sudo tcpdump -i en0 -c 10"; SUDO="yes" ;;
        3) TOOL="ngrep"; CMD="sudo ngrep -d en0"; SUDO="yes" ;;
        4) TOOL="mitmproxy"; CMD="$VENV_DIR/bin/mitmproxy"; SUDO="no" ;;
        5) TOOL="dnsrecon"; CMD="$VENV_DIR/bin/dnsrecon"; SUDO="no" ;;
        6) TOOL="whois"; CMD="whois"; SUDO="no" ;;
        7) TOOL="dig"; CMD="dig"; SUDO="no" ;;
        8) TOOL="nslookup"; CMD="nslookup"; SUDO="no" ;;
        9) TOOL="sublist3r"; CMD="$VENV_DIR/bin/sublist3r"; SUDO="no" ;;
        10) TOOL="amass"; CMD="amass enum"; SUDO="no" ;;
        11) TOOL="nmap"; CMD="nmap -Pn -sS -F"; SUDO="no" ;;
        12) TOOL="fping"; CMD="fping -a -g"; SUDO="no" ;;
        13) TOOL="bettercap"; CMD="sudo bettercap -iface en0"; SUDO="yes" ;;
        14) TOOL="netcat"; CMD="nc"; SUDO="no" ;;
        15) TOOL="socat"; CMD="socat"; SUDO="no" ;;
        16) TOOL="tcpflow"; CMD="sudo tcpflow -i any"; SUDO="yes" ;;
        17) TOOL="report"; CMD="generate_html_report"; SUDO="no" ;;
        0) echo -e "${RED}Exiting...${NC}"; log_message "Exiting Kali Tools menu"; break ;;
        *) echo -e "${RED}Invalid option${NC}"; log_message "Invalid menu option selected: $choice"; read; continue ;;
    esac

    # Check if tool is available (except for report)
    if [ "$TOOL" != "report" ] && ! check_tool "$TOOL"; then
        echo -e "${RED}Error: $TOOL not found. Please run install.sh to install it.${NC}"
        log_message "Error: $TOOL not found"
        echo -e "${CYAN}Press Enter to return to menu...${NC}"
        read
        continue
    fi

    # Warn about sudo requirement
    if [ "$SUDO" == "yes" ]; then
        echo -e "${YELLOW}Note: $TOOL requires sudo. Ensure you run with 'sudo kali_tools' if permission issues occur.${NC}"
        log_message "Warning: $TOOL requires sudo"
    fi

    # Execute tool
    case $choice in
        6)
            read -p "Domain: " dom
            read -e -p "Save WHOIS HTML to file (e.g., $HOME/kali_tools/whois.html): " filepath
            if [ -z "$filepath" ]; then
                filepath="$HOME/kali_tools/whois_$(date +%Y%m%d_%H%M%S).html"
            fi
            echo -e "${CYAN}Running $TOOL $dom...${NC}"
            log_message "Running $TOOL $dom, saving to $filepath"
            if $CMD "$dom" | awk 'BEGIN {print "<html><body><pre>"} {print} END {print "</pre></body></html>"}' > "$filepath"; then
                echo -e "${GREEN}WHOIS report saved to: $filepath${NC}"
                log_message "WHOIS report saved to $filepath"
            else
                echo -e "${RED}Error running $TOOL${NC}"
                log_message "Error running $TOOL $dom"
            fi
            ;;
        7|8|9|10|11|12)
            read -p "Target (domain/IP for $TOOL): " tgt
            echo -e "${CYAN}Running $CMD $tgt...${NC}"
            log_message "Running $CMD $tgt"
            if $CMD "$tgt"; then
                log_message "$TOOL $tgt executed successfully"
            else
                echo -e "${RED}Error running $TOOL${NC}"
                log_message "Error running $TOOL $tgt"
            fi
            ;;
        1|2|3|13|16)
            echo -e "${CYAN}Running $CMD...${NC}"
            log_message "Running $CMD"
            if $CMD; then
                log_message "$TOOL executed successfully"
            else
                echo -e "${RED}Error running $TOOL${NC}"
                log_message "Error running $TOOL"
            fi
            ;;
        4|14|15)
            echo -e "${CYAN}Running $CMD...${NC}"
            log_message "Running $CMD"
            if $CMD; then
                log_message "$TOOL executed successfully"
            else
                echo -e "${RED}Error running $TOOL${NC}"
                log_message "Error running $TOOL"
            fi
            ;;
        17)
            read -p "Target (domain or IP): " target
            input_type=$(validate_input "$target")
            if [ "$input_type" == "invalid" ]; then
                echo -e "${RED}Error: Invalid domain or IP address${NC}"
                log_message "Invalid input: $target"
                echo -e "${CYAN}Press Enter to return to menu...${NC}"
                read
                continue
            fi
            read -e -p "Save report to file (e.g., $HOME/kali_tools/export_info.html): " filepath
            if [ -z "$filepath" ]; then
                filepath="$HOME/kali_tools/export_info_$(date +%Y%m%d_%H%M%S).html"
            fi
            echo -e "${CYAN}Generating advanced report for $target ($input_type)...${NC}"
            generate_html_report "$target" "$input_type" "$filepath"
            ;;
    esac

    echo -e "${CYAN}\nPress Enter to return to menu...${NC}"
    read
done