#!/bin/bash

# copy SampleCode.xcconfig.local to every SampleCode.xcconfig file in project
find */. -name "SampleCode.xcconfig" -exec cp SampleCode.xcconfig.local {} \;
