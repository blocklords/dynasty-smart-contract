// var OrbNft = artifacts.require("./OrbNFT.sol");
// var HeroNft = artifacts.require("./HeroNFT.sol");
// var BannerNft = artifacts.require("./BannerNFT.sol");
var NFTImportHub = artifacts.require("./NFTImportHub.sol");

const owner = "0xC6EF8A96F20d50E347eD9a1C84142D02b1EFedc0";
const heroNft = "0xf4927d0a665Fb4c5D7639C08aA24EEAc643Fe29A";
const bannerNft = "0x0E6eef3897B9e98A3C71f61c50997907d5457Ec1";
const verifier = "0x5bDed8f6BdAE766C361EDaE25c5DC966BCaF8f43";

module.exports = function(deployer, network, accounts) {
   
    deployer.deploy(NFTImportHub, owner, heroNft, bannerNft, verifier).then(function(){
        console.log(`${accounts[0]} deployed NFT Import Hub on ${NFTImportHub.address}`);
    });
};
 
