#pragma once

#define _WIN32_WINNT 0x0A00
#define NTDDI_VERSION 0x0A000000
#define NOMINMAX
#define WIN32_LEAN_AND_MEAN

#include <winsock2.h>
#include <windows.h>
#include <iphlpapi.h>
#include <ifmib.h>
#include <string>
#include <vector>
#include <map>
#include <functional>
#include <cstdint>
#include <sstream>
#include <fstream>
#include <algorithm>
#include <cwctype>
