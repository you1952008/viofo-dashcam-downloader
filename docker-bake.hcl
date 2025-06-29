group "default" {
  targets = ["viofo-pipeline"]
}

target "viofo-pipeline" {
  context    = "./docker-build"
  dockerfile = "Dockerfile"
  tags       = [
    "ryanwayne/viofo-pipeline:1.2.1",
    "ryanwayne/viofo-pipeline:latest"
  ]
  platforms  = [
    "linux/amd64",
    "linux/arm/v6",
    "linux/arm64"
  ]
}