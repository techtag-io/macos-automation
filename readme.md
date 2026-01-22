# macOS Automations & Deployment Tools (crafted with Gemini)

A collection of production-ready Bash scripts and configurations designed for enterprise macOS management. These tools focus on automating life-cycle management, security compliance, and user-facing deployment workflows.

🚀 Key Features

* **Zero-Touch Deployment:** Scripts designed for Jamf Pro integration to facilitate remote-first onboarding.
* **Automated Security Patching:** Workflows to address zero-day vulnerabilities in critical apps like Chrome, Slack, and Zoom.
* **Cross-Architecture Support:** Intelligent logic to handle differences between Apple Silicon (M1/M2/M3) and Intel-based Macs.
* **User-Centric UI:** Integration with `swiftDialog` to provide branded, transparent progress markers for end-users.

📂 Repository Structure

* `scripts/system/`: Core OS management, including bootable drive creation and system updates.
* `scripts/network/`: Automation for host file management and network configuration.
* `scripts/security/`: Logic for vulnerability remediation and role-based access controls.

🛠️ Featured Script: macOS Update Deployer

This utility manages the high-stakes process of OS upgrades.

* **Problem:** Apple Silicon requires user authentication for volume ownership during updates.
* **Solution:** This script detects the architecture, prompts for secure credentials via a custom UI, and leverages `startosinstall` to ensure 100% success rates.

👔 About the Author

**Travis Green** is an IT & Security Manager with 13+ years of experience specializing in automation and high-performing team leadership. Currently pursuing a BS in Computer Science at WGU, Travis focuses on building "Scale Quietly, Fail Loudly" infrastructure.

---
*Disclaimer: These scripts are intended for use in managed enterprise environments. Always test in a sandbox before global deployment.*
