var Nft = artifacts.require("./HouseNFT.sol");

const owner = "0xC6EF8A96F20d50E347eD9a1C84142D02b1EFedc0";
const verifier = "0x5bDed8f6BdAE766C361EDaE25c5DC966BCaF8f43";

module.exports = function(deployer, network, accounts) {
   
    deployer.deploy(Nft, owner, verifier).then(function(){
        console.log(`${accounts[0]} deployed House Nft on ${Nft.address}`);
    });
};
 
