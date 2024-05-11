var Chest = artifacts.require("./Chest.sol");

const owner = "0xC6EF8A96F20d50E347eD9a1C84142D02b1EFedc0";
const factory = "0xB25E33Ff1ae409AdeD2a0bd8E4fc2c9C451D4889";
const heroNft = "0xf4927d0a665Fb4c5D7639C08aA24EEAc643Fe29A";
const bannerNft = "0x0E6eef3897B9e98A3C71f61c50997907d5457Ec1";
const orbNft = "0xf0d600e2A2408D3a7aFbFCb37D51f51cA31A8C20";
const lrds = "0x9650784847c61b6da1E0aA51A9a9Fe7914Bc60b2";
const bank = "0x5bDed8f6BdAE766C361EDaE25c5DC966BCaF8f43";
const verifier = "0x5bDed8f6BdAE766C361EDaE25c5DC966BCaF8f43";

module.exports = function(deployer, network, accounts) {
   
    deployer.deploy(Chest, owner, factory, heroNft, bannerNft, orbNft, lrds, bank, verifier).then(function(){
        console.log(`${accounts[0]} deployed Chest on ${Chest.address}`);
    });
};
 
