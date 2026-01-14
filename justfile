_docker-build NAME:
  nix build '.#{{NAME}}'
  cp ./result {{NAME}}.tar.gz
  skopeo inspect docker-archive:./{{NAME}}.tar.gz

docker: (_docker-build "docker")

docker-with-tag: (_docker-build "docker-with-tag")

