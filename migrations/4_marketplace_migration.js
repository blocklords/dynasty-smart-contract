var Marketplace = artifacts.require("./Marketplace.sol");

const owner = "0xC6EF8A96F20d50E347eD9a1C84142D02b1EFedc0";
const feeReceiver = "0x5bDed8f6BdAE766C361EDaE25c5DC966BCaF8f43";
const feeRate = 10;	// 1 = 0.1%, 10 = 1%, 100 = 10%;

module.exports = function(deployer, network, accounts) {
   
    deployer.deploy(Marketplace, owner, feeReceiver, feeRate).then(function(){
        console.log(`${accounts[0]} deployed Marketplace on ${Marketplace.address}`);
    });
};
 
