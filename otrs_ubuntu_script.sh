#!/bin/bash

# Script de instalação do OTRS para Sistemas Operacionais Debian/Ubuntu
#
# Desenvolvido por Infracerta Consultoria
# Sempre recomendamos analisar o script antes de instala-lo!


#Variaveis
# Coloque a versão do OTRS que deseja instalar na variavel abaixo
OTRS_VERSION="6.0.16"
OTRS_INSTALL_DIR="/opt/"
REQ_PACKAGES="libapache2-mod-perl2 libdbd-mysql-perl libtimedate-perl libnet-dns-perl libnet-ldap-perl libio-socket-ssl-perl libpdf-api2-perl libdbd-mysql-perl libsoap-lite-perl libgd-text-perl libtext-csv-xs-perl libjson-xs-perl libgd-graph-perl libapache-dbi-perl libdigest-md5-perl apache2 libapache2-mod-perl2 mysql-server libarchive-zip-perl libxml-libxml-perl libtemplate-perl libyaml-libyaml-perl libdatetime-perl libmail-imapclient-perl"
MYSQL_CONF_DIR="/etc/mysql/mysql.conf.d"

MainMenu()
{
	clear
	echo "########################################################"
	echo "# Bem-vindo ao Instalador do OTRS                      #"
	echo "#  -------------------------------------------------   #"
	echo "########################################################"

	echo "########################################################"
	echo "# Digite uma das opcoes abaixo:                        #"
	echo "#  -------------------------------------------------   #"
	echo "# 1 - Verificar requisitos de instalacao(Recomendavel) #"
	echo "# 2 - Instalar pacotes necesários para o OTRS          #"
	echo "# 3 - Iniciar a instalacao do OTRS                     #"
	echo "# 4 - Sair do Instalador                               #"
	echo "########################################################"
	read OPTION

	CallCase
}

# Instalação dos pacotes necessários para o OTRS
InstallREQPKG()
{
	echo -n "Iniciando a instalacao as dependencias..........."
	apt-get update 1> /dev/null && apt-get -y install ${REQ_PACKAGES}

	if [ $? != 0 ]; then
		clear
		echo "Ocorreu um erro, execute "bash -x nomedoscript" para mais informacoes...";exit
	else
		clear
		echo "Iniciando a instalacao as dependencias...........OK"
	fi
	echo -n "Pressione q para sair do script ou qualquer outra tecla para voltar ao menu inicial..."
	read KEY
	if [ ${KEY} = "q"]; then
		exit
	else
		MainMenu
	fi
}

# Essa etapa faz uma verificação básica no sistema
BasicCheck()
{
	echo "Executando verificacoes basicas do sistema"
	#Resolucao DNS
	nslookup otrs.org | grep "Non-authoritative answer:" 1> /dev/null
	if [ $? = 1 ];then
		echo "ERRO: Impossivel resolver otrs.org, favor verificar suas configuracoes de DNS..."
		exit
	else
		echo "Resolucao DNS.........................OK"
	fi
	#Verifica se o usuario atual e o root
	id |grep "uid=0" 1> /dev/null
	if [ $? = 1 ] ;then
		echo "ERRO: E necessario fazer login como root para iniciar a instalacao.";exit
	else
		echo "Usuario root..........................OK"
	fi

	echo -n "Pressione uma tecla pra continuar..."
	read KEY

	MainMenu
}

# Instalação e configuração do pacote OTRS
InstallOTRS()
{

	#Fazendo o download do pacote do OTRS:
	echo -n "Baixar arquivo do OTRS....................."
	cd ${OTRS_INSTALL_DIR}
	wget http://ftp.otrs.org/pub/otrs/otrs-${OTRS_VERSION}.tar.gz 1> /dev/null
	if [ $? != 0 ]; then
		clear
		echo "Ocorreu um erro ao baixar o pacote do OTRS,  execute "bash -x nomedoscript" para mais informacoes...;exit"
	else
		echo "OK"
	fi

	# Descompactando o arquivo
	echo -n "Descompactando o arquivo..................."
	cd ${OTRS_INSTALL_DIR}
	tar -zxvf otrs\-${OTRS_VERSION}\.tar\.gz 1> /dev/null
	if [ $? = 0 ]; then
		echo "OK"
	else
		clear
		echo "Ocorreu um erro ao descompactar, verifique o arquivo e tente novamente.";exit
	fi

	# Renomeando o diretorio OTRS
	echo -n "Renomeando o diretorio do OTRS............."
	mv otrs-${OTRS_VERSION} otrs 1> /dev/null
	if [ $? = 0 ]; then
		echo "OK"
	else
		clear
		echo "Erro ao renomear o diretorio , verifique se o diretorio existe ou ja foi renomeado. ";exit
	fi

	#Criando links simbolicos e movendo os arquivos
	echo -n "Criando links simbolicos..................."
	ln -s ${OTRS_INSTALL_DIR}otrs/scripts/apache2-httpd.include.conf /etc/apache2/conf-enabled/ 1> /dev/null
	if [ $? = 0 ]; then
		echo "OK"
	else
		echo "Erro ao criar link simbólico, verifique se o arquivo existe...";exit
	fi

	echo -n "Movendo arquivos necessários..............."
	mv ${OTRS_INSTALL_DIR}otrs/Kernel/Config.pm.dist ${OTRS_INSTALL_DIR}/otrs/Kernel/Config.pm 1> /dev/null
	if [ $? = 0 ]; then
		echo "OK"
	else
		echo "Erro ao mover os arquivos, verifique se ja nao foram foram movidos ou se eles existem";exit
	fi

	#Adicionando o user OTRS e setando as permissoes necessarias
	echo -n "Configurando usuarios e  permissoes........"
	useradd -d ${OTRS_INSTALL_DIR}otrs/ -c 'OTRS user' otrs 1> /dev/null
	usermod -G www-data otrs 1> /dev/null
	${OTRS_INSTALL_DIR}otrs/bin/otrs.SetPermissions.pl --otrs-user otrs --web-group www-data ${OTRS_INSTALL_DIR}otrs 1> /dev/null
	if [ $? = 0 ]; then
		echo "OK"
	else
		echo "Ocorreu durante essa etapa, verifique o log acima";exit
	fi

	#Configurando a cron
	echo -n "Configurando e iniciando a crontab........."
	cd ${OTRS_INSTALL_DIR}otrs/var/cron/ && for foo in *.dist; do cp $foo `basename $foo .dist`; done
	chown otrs:www-data /opt/otrs/var/cron/otrs_daemon
	if [ $? = 0 ]; then
		echo "OK"
	else
		echo "Ocorreu durante essa etapa, verifique o log acima";exit
	fi

	#Ativando o modo headers e
	echo -n "Ativando modulos e reiniciando o apache...."
	a2enmod headers 1> /dev/null
	a2dismod mpm_event 1> /dev/null
	a2enmod mpm_prefork 1> /dev/null
	service apache2 restart 1> /dev/null
	if [ $? = 0 ]; then
		echo "OK"
	else
		echo "Erro ao reiniciar o apache.";exit
	fi

	#Ajustando parametros necessarios do MySQL:
	echo -n "Alterando parametros do Mysql.............."
		sed -i "s/.*max_allowed_packet.*/#max_allowed_packet = 128M/" ${MYSQL_CONF_DIR}/mysqld.cnf
		echo "[mysqld]" > ${MYSQL_CONF_DIR}/custom.cnf
		echo "character-set-server = utf8" >> ${MYSQL_CONF_DIR}/custom.cnf
		echo "collation-server= utf8_general_ci" >> ${MYSQL_CONF_DIR}/custom.cnf
		echo "innodb_log_file_size = 512M" >> ${MYSQL_CONF_DIR}/custom.cnf
		echo "max_allowed_packet = 128M" >> ${MYSQL_CONF_DIR}/custom.cnf
	if [ $? = 0 ]; then
		echo "OK"
	else
		echo "Erro ao configurar o Mysql.";exit
	fi
	echo -n "Reiniciando o mysql........................"
	service mysql restart 1> /dev/null
	if [ $? = 0 ]; then
		echo "OK"
	else
		echo "Erro ao reiniciar o Mysql.";exit
	fi
}

CallCase()
{
	case "$OPTION" in
    1) BasicCheck
		;;
		2) InstallREQPKG
		;;
		3) InstallOTRS
		;;
		4) exit
		;;
		*) MainMenu
	esac
}
MainMenu
