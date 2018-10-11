// https://github.com/hashicorp/hcl#syntax
# single line comment
// another single line comment

/*
multi-line
comment
*/

// Values are assigned with the syntax key = value (whitespace doesn't matter). The value can be any primitive: a string, number, boolean, object, or list.

key1 = value1

// Strings are double-quoted and can contain any UTF-8 characters. 
str1 = "Hello, World"

// multi-line strings
// https://en.wikipedia.org/wiki/Here_document
<<EOF
hello
world
EOF

// array
array1 = ["foo", "bar", 42]

service {
    key = "value"
}

service {
    key = "value"
}

// object
variable "ami" {
    description = "the AMI to use"
}

/*
equivalent to the following json:

{
  "variable": {
      "ami": {
          "description": "the AMI to use"
        }
    }
}
*/
