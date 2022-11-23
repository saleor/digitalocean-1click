#!/bin/bash

groupadd -r saleor 
useradd -r -g saleor saleor

fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

echo 'image/webp webp' >> /etc/mime.types

export SECRET_KEY=`cat /dev/urandom | tr -dc '[:alpha:]' | fold -w ${1:-80} | head -n 1`

mkdir -p /srv/app
cd /srv/app

git clone https://github.com/saleor/saleor .

mkdir -p /srv/app/media /srv/app/static 
chown -R saleor:saleor /srv/app/

sed -i 's/< "3.10"/<= "3.10"/g' requirements_dev.txt
sed -i 's/< "3.10"/<= "3.10"/g' requirements.txt

pip install -r requirements.txt

sudo -u postgres createdb saleor
sudo -u postgres psql <<EOF 
CREATE USER saleor WITH SUPERUSER PASSWORD 'saleor';
GRANT CONNECT ON DATABASE saleor TO saleor;
GRANT USAGE ON SCHEMA public TO saleor;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO saleor;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO saleor;
EOF

cat <<EOF > manage.py
#!/usr/bin/env python3
import os
import sys

if __name__ == "__main__":
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "saleor.settings")

    from django.core.management import execute_from_command_line

    import collections
    collections.MutableSequence = collections.abc.MutableSequence

    execute_from_command_line(sys.argv)
EOF

python3 manage.py migrate
python3 manage.py collectstatic --noinput
python3 manage.py populatedb --createsuperuser
