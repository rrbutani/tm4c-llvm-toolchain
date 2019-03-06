workflow "Build toolchain container and push to Docker Hub" {
  on = "push"
  resolves = [
    "Log into Docker Hub",
    "Push to Docker Hub",
    "Tag toolchain container",
    "Tag with version",
  ]
}

action "Build toolchain container" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Log into Docker Hub"]
  args = "build -t arm-llvm-toolchain -f env/Dockerfile ."
}

action "Log into Docker Hub" {
  uses = "actions/docker/login@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  secrets = ["DOCKER_USERNAME", "DOCKER_PASSWORD"]
}

action "Tag toolchain container" {
  uses = "actions/docker/tag@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Build toolchain container"]
  args = "arm-llvm-toolchain rrbutani/arm-llvm-toolchain"
}

action "Push to Docker Hub" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = [
    "Tag toolchain container",
    "Tag with version",
  ]
  args = "push rrbutani/arm-llvm-toolchain"
}

action "Tag with version" {
  uses = "docker://rrbutani/docker-version-tag"
  needs = ["Build toolchain container"]
  args = "arm-llvm-toolchain rrbutani/arm-llvm-toolchain env/Dockerfile"
}
