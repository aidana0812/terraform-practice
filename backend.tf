terraform {
  backend "s3" {
    bucket = "terraform.practice.dana" #the name of existing s3 bucket 
    region = "us-east-1"
    key    = "dev-env" #this is how you name state file 
    # dynamodb_table = "state.file.locking"
  }
}