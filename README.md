## Description
Ruby script designed to help with continuous integration.

## Installation

1. Clone the repository
2. Modify `ci.rb` file.
Depending on your platform override the building, testing and uploading methods.
3. To integrate with github you will need and access token, write it inside the integrate method.
4. `bundle install` to install dependencies

## Usage

`-u` Github username

`-n` Repository name

`-b` Branch

`-p` Pull Request number

Distribute master branch

```
ruby ci.rb distribute -u fjbelchi -n clean-iOS-architecture-generator -b master
```

Integrate PR #26 into master branch
```
ci.rb integrate -u fjbelchi -n clean-iOS-architecture-generator -b master -p 26
```
