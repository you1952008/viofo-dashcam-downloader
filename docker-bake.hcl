group "default" {
  targets = ["viofo-dashcam-downloader"]
}

target "viofo-dashcam-downloader" {
  context    = "./docker-build"
  dockerfile = "Dockerfile"
  tags       = ["ryanwayne/viofo-dashcam-downloader:1.0.3"]
  platforms  = [
    "linux/amd64",   # For Windows via Docker Desktop/WSL2
    "linux/arm/v6",  # For Pi Zero 1.1
    "linux/arm64"    # For Pi 5
  ]
}