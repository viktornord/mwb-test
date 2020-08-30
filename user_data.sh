#!/bin/bash -xe
apt-get update
apt install nodejs -y
apt install npm -y
git clone https://github.com/viktornord/mwb-test.git
cd mwb-test
npm i
node index.js &
