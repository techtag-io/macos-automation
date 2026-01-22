#!/bin/sh

echo "Expanding /etc/hosts"
echo ""
echo ""
cat /etc/hosts
echo ""
echo ""


echo "Looking for contentcatcher and removing it..."
#line 1 and commented
sed -i '' -e 's/127.0.0.1 contentcatcher.cloud-protect.net//' /etc/hosts
sed -i '' -e 's/#127.0.0.1 contentcatcher.cloud-protect.net//' /etc/hosts

echo "Looking for login.mailchimp and removing it..."
#line 2 and commented
sed -i '' -e 's/127.0.0.1 login.mailchimp.com//' /etc/hosts
sed -i '' -e 's/#127.0.0.1 login.mailchimp.com//' /etc/hosts

echo "Looking for contentcatcher-eu and removing it..."
#line 3 and commented
sed -i '' -e 's/127.0.0.1 contentcatcher-eu.cloud-protect.net//' /etc/hosts
sed -i '' -e 's/#127.0.0.1 contentcatcher-eu.cloud-protect.net//' /etc/hosts


echo "Expanding /etc/hosts after running script"
echo ""
echo ""
cat /etc/hosts
echo ""
echo ""

exit 0
