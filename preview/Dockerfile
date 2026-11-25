FROM litespeedtech/openlitespeed:1.9.3-lsphp84

ADD https://github.com/wp-cli/wp-cli/releases/download/v2.11.0/wp-cli-2.11.0.phar /usr/local/bin/wp
RUN chmod +x /usr/local/bin/wp

# 本番のコアサーバーに合わせ、アップロードの進み具合をセッションへ書き込まない
RUN echo 'session.upload_progress.enabled = Off' > /usr/local/lsws/lsphp84/etc/php/8.4/mods-available/zz-session.ini
