// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Hello.sol";

contract HelloTest is Test {
    Hello hello;
    
    function setUp() public {
        hello = new Hello();
    }
    
    function testInitialGreeting() public {
        assertEq(hello.greeting(), "Hello, Uniswap V3!");
    }
    
    function testSetGreeting() public {
        hello.setGreeting("Hello, World!");
        assertEq(hello.greeting(), "Hello, World!");
    }
}
