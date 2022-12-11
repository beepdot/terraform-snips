resource "local_file" "local2" {
    filename = "local2.txt"
    content = var.localfile["local2"]
    file_permission = "0700"
}