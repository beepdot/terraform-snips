resource "local_file" "main1" {
  filename = "main1.txt"
  content = "main1"
}

resource "local_file" "main2" {
  filename = "main2.txt"
  content = "main2"
}

resource "random_pet" "petname" {
  length = var.length
  prefix = var.prefix[2]
  separator = var.separator
}