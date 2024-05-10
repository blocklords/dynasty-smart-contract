// var OrbNft = artifacts.require("./OrbNFT.sol");
// var HeroNft = artifacts.require("./HeroNFT.sol");
// var BannerNft = artifacts.require("./BannerNFT.sol");
var Factory = artifacts.require("./NftFactory.sol");

const owner = "0xC6EF8A96F20d50E347eD9a1C84142D02b1EFedc0";
const orbNft = "0xA5a14F42696D0860135982d28ae30f7dEaF55C98";
const heroNft = "0xe1a65768d2a28823a9E90Bd6750E811a18abDbec";
const bannerNft = "0xcF1F002CDBe8119Cb6604ccDD31e52735a8CF7c2";

module.exports = function(deployer, network, accounts) {
   
    deployer.deploy(Factory, owner, orbNft, heroNft, bannerNft).then(function(){
        console.log(`${accounts[0]} deployed Orb Nft on ${Factory.address}`);
    });
};
 
