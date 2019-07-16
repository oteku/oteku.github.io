#!/bin/bash
 
cd src && zola build && cp -fR public/* .. && rm -r public && cd -
