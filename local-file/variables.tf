variable "length" {
  default = 1
  type = number
  description = "Number of words in per name"
}

variable "prefix" {
  default = ["Mrs", "Mr", "Sir"]
  type = list(string)
  description = "Prefix value"
}

variable "separator" {
#  default = "."
  type = string
  description = "Separator"
}

variable "localfile" {
  type = map(number)
  default = {
    "local1": 123
    "local2": 456
  }
}

variable "betta" {
  type = object({
    name = string
    color = string
    age = number
    food = list(string)
    favorite = bool
  })

  default = {
    age = 3
    color = "blue"
    favorite = true
    food = [ "rice", "veggies" ]
    name = "bettappa"
  }
}

variable "kushi" {
  type = tuple([string, number, bool])
  default = ["Kushi", 5, false]
}