openssl rsa -in transip_private.key -out transip.key

docker run -it --rm -v /path/to/config:/config -v /path/to/auth:/auth --env-file env.letsencrypt haproxy:le /usr/local/scripts/letsencrypt.sh
docker run -it --rm -v /path/to/config:/config haproxy:le /usr/local/scripts/haproxy.sh

docker run -d -p 80:80 -p 443:443 -v /path/to/config:/config haproxy:le