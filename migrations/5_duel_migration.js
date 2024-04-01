var Duel = artifacts.require("./Duel.sol");

const owner = "0xC6EF8A96F20d50E347eD9a1C84142D02b1EFedc0";
const heroNft = "0xB2379391F713F7653c58850058AE19F50559DE42";
const verifier = "0x5bDed8f6BdAE766C361EDaE25c5DC966BCaF8f43";

module.exports = function(deployer, network, accounts) {
   
    deployer.deploy(Duel, owner, heroNft, verifier).then(function(){
        console.log(`${accounts[0]} deployed Duel on ${Duel.address}`);
    });
};
 
