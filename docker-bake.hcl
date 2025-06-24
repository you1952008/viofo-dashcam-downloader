group "default" {
  targets = ["viofo-pipeline"]
}

target "viofo-pipeline" {
  context    = "./docker-build"
  dockerfile = "Dockerfile"
  tags       = ["ryanwayne/viofo-pipeline:1.1.1"]
  platforms  = [
    "linux/amd64",   # For Windows via Docker Desktop/WSL2
    "linux/arm/v6",  # For Pi Zero 1.1
    "linux/arm64"    # For Pi 5
  ]
}