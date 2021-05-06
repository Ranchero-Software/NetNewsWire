#!/bin/bash

cat << "EOF"
   __ _  ____  ____  __ _  ____  _  _  ____  _  _  __  ____  ____ 
  (  ( \(  __)(_  _)(  ( \(  __)/ )( \/ ___)/ )( \(  )(  _ \(  __)
  /    / ) _)   )(  /    / ) _) \ /\ /\___ \\ /\ / )(  )   / ) _) 
  \_)__)(____) (__) \_)__)(____)(_/\_)(____/(_/\_)(__)(__\_)(____)

EOF

echo This script will create a SharedXcodeSettings folder and a DeveloperSettings.xcconfig file.
echo 
echo We need to ask a few questions first.
echo 
read -p "Press enter to get started."


# Get the user's Developer Team ID
echo 1. What is your Developer Team ID? You can get this from developer.apple.com.
read devTeamID

# Get the user's Org Identifier
echo 2. What is your organisation identifier? e.g. com.developername
read devOrgName

echo Creating SharedXcodeSettings Folder
mkdir -p ../SharedXcodeSettings

echo Creating DeveloperSettings.xcconfig

cat <<file >> ../SharedXcodeSettings/DeveloperSettings.xcconfig
CODE_SIGN_IDENTITY = Mac Developer
DEVELOPMENT_TEAM = $devTeamID
CODE_SIGN_STYLE = Automatic
ORGANIZATION_IDENTIFIER = $devOrgName
DEVELOPER_ENTITLEMENTS = -dev
PROVISIONING_PROFILE_SPECIFIER =
file

echo Done! 
