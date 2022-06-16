#!/bin/bash
# Setup para configurar el servidor para la aplicación
# Guarde la ruta actual
export APPDIR=$(pwd)

# Instalar dependencias
sudo apt-get update --fix-missing
sudo apt-get install -y postgresql postgresql-contrib libpq-dev \
nginx make build-essential g++ upstart vim curl openssl libssl-dev \
rlwrap uglifyjs

# Install nvm: node-version manager
# https://github.com/creationix/nvm
curl https://raw.github.com/creationix/nvm/master/install.sh | sh

# Load nvm and install latest production node
source $HOME/.nvm/nvm.sh
nvm install v0.10.12
nvm use v0.10.12

# Instala emacs por si necesito editar algùn archivo
# https://launchpad.net/~cassou/+archive/emacs
sudo apt-add-repository -y ppa:cassou/emacs
sudo apt-get update
sudo apt-get install -y emacs24 emacs24-el emacs24-common-non-dfsg

# git pull and install dotfiles as well
cd $HOME
if [ -d ./dotfiles/ ]; then
    mv .dotfiles .dotfiles.old
fi
if [ -d .emacs.d/ ]; then
    mv .emacs.d .emacs.d~
fi
git clone https://github.com/alejomongua/dotfiles.git .dotfiles
ln -sf .dotfiles/.emacs.d .
ln -sb .dotfiles/.screenrc .
ln -sb .dotfiles/.bash_profile .
ln -sb .dotfiles/.bashrc .
ln -sb .dotfiles/.bashrc_custom .
ln -sf .dotfiles/.emacs.d .
source ~/.bashrc

# Instalar dependencias de la aplicación
cd $APPDIR
npm install
cd $APPDIR/api
npm install
cd $APPDIR/interfaz
npm install

# Crear la base de datos, los permisos y la extension HSTORE
cd $APPDIR
sudo -u postgres psql -f setupdb.sql

# Correr las migraciones
cd $APPDIR/api
node node_modules/sequelize/bin/sequelize -m -e production

# Crea el directorio para los logs
sudo mkdir /var/log/myApplication

# Actualiza las rutas
cd $APPDIR
export NODE_BIN=$(which node)
sed "s|/path/to/app|$APPDIR|g" nginx.conf >> nginx.conf.temp
mv -f nginx.conf.temp nginx.conf
# verifica si es staging para actualizar la url
if [ "$1" == "staging" ]
then
  sed "s|server.co|myapp.ekii.co|g" nginx.conf >> nginx.conf.temp
  mv -f nginx.conf.temp nginx.conf
fi
sed "s|/home/alejo/.nvm/v0.10.12/bin/node|$NODE_BIN|g" upstart.conf >> upstart.conf.temp
mv -f upstart.conf.temp upstart.conf
sed "s|/path/to/app|$APPDIR|g" upstart.conf >> upstart.conf.temp
mv -f upstart.conf.temp upstart.conf

# Crea el archivo secrets.json
echo -ne "Usuario para correos enviados: "
read username
echo -ne "Password de ${username}: "
read -s password
echo -ne "Facebook app id: "
read fbappid
echo -ne "Facebook app secret: "
read fbappsecret
echo -e ""

echo '{' >> $APPDIR/api/config/secrets.json
echo '  "facebook": {' >> $APPDIR/api/config/secrets.json
echo '    "appId": "${fbappid}",' >> $APPDIR/api/config/secrets.json
echo '    "appSecret": "${fbappsecret}"' >> $APPDIR/api/config/secrets.json
echo '  },' >> $APPDIR/api/config/secrets.json
echo '  "email": {' >> $APPDIR/api/config/secrets.json
echo '    "username": "${username}",' >> $APPDIR/api/config/secrets.json
echo '    "password": "${password}"' >> $APPDIR/api/config/secrets.json
echo '  }' >> $APPDIR/api/config/secrets.json
echo '}' >> $APPDIR/api/config/secrets.json

# Crea el usuario superadministrador
echo -ne "Correo usuario superadministrador: "
read superadmin

echo "var usuarios = require('./api/helpers/db_helper').usuarios;" >> $APPDIR/tmp.js
echo "var async = require('async');" >> $APPDIR/tmp.js
echo "usuarios.create({" >> $APPDIR/tmp.js
echo "  email:'${superadmin}'," >> $APPDIR/tmp.js
echo "  nombre: 'Administrador'," >> $APPDIR/tmp.js
echo "  username: 'superadmin'," >> $APPDIR/tmp.js
echo "  superadministrador: true" >> $APPDIR/tmp.js
echo "}, null, function(e,result){" >> $APPDIR/tmp.js
echo "  if (e){ " >> $APPDIR/tmp.js
echo "    console.log('Error');" >> $APPDIR/tmp.js
echo "    console.log(e);" >> $APPDIR/tmp.js
echo "    process.exit(code=-1)" >> $APPDIR/tmp.js
echo "    return;" >> $APPDIR/tmp.js
echo "  }" >> $APPDIR/tmp.js
echo "  console.log('terminado');" >> $APPDIR/tmp.js
echo "  console.log(result);" >> $APPDIR/tmp.js
echo "  process.exit(code=0)" >> $APPDIR/tmp.js
echo "});" >> $APPDIR/tmp.js
NODE_ENV=production node tmp.js
rm -f tmp.js

# Arranca el servicio
sudo cp -f $APPDIR/upstart.conf /etc/init/myApplication.conf
sudo start myApplication

# Remplazar facebook appId
sed "s|myApplication\.FB\.APPID = '[0-9]\{10,\}';|myApplication.FB.APPID = '${fbappid}';|g" $APPDIR/interfaz/public/js/misScripts.js >> misScripts.js.temp
mv misScripts.js.temp $APPDIR/interfaz/public/js/misScripts.js

# Minificar javascripts
$APPID/minify.sh

# Vincula la página en nginx
sudo rm -f /etc/nginx/sites-enabled/*
sudo ln -s $APPDIR/nginx.conf /etc/nginx/sites-enabled/default
sudo service nginx restart