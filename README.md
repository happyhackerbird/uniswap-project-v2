# Salatswap 
Salatswap (Saladswap) is my Uniswap V2 implementation that I'm building to learn how all the Uniswap smart contracts work and to gain a deeper understanding of the mathematics behind it. 

### How to run 
Clone, then you can install the dependencies & run all the tests with
```forge test```

### Todo 
- [x] Adding and removing liquidity 
- [x] Token swapping
- [x] Reentrancy attack protection (Checks Effects Interactions Pattern)
- [x] Price oracles 
    - [x] use uint112 for reserves and binary fixed point for calculations
    - [x] gas optimizations
    - [x] test cumulative prices
- [x] Restructure tests 
- [x] Factory contract 
- [x] Router and library contracts (more tests needed)

Add: 
Protocol fees,
Flash loans
