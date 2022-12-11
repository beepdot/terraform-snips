resource "local_file" "local1" {
  filename = "local1.txt"
  content = var.localfile["local1"]
}