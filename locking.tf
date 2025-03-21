resource "aws_dynamodb_table" "locking_file" {
  name         = "state.file.locking"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
