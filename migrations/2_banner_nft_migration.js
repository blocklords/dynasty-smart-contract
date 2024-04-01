var Nft = artifacts.require("./BannerNFT.sol");

const owner = "0xC6EF8A96F20d50E347eD9a1C84142D02b1EFedc0";

module.exports = function(deployer, network, accounts) {
   
    deployer.deploy(Nft, owner).then(function(){
        console.log(`${accounts[0]} deployed Banner Nft on ${Nft.address}`);
    });
};
 
