#!/bin/bash
 
zola build -b src && cp -fR public/* . && rm -r public
