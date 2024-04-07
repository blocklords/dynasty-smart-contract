const BannerNFT = artifacts.require("BannerNFT");

contract("BannerNFT", accounts => {
  let bannerNFT;
  const verifier = accounts[1];

  beforeEach(async () => {
    bannerNFT = await BannerNFT.new(accounts[0], verifier);
  });

  // signatures
  async function signNft(to, tokenId) {
    let nonce = await bannerNFT.nonce(to);

    let bytes5 = web3.eth.abi.encodeParameters(["uint256"],[parseInt(tokenId.toString())]);
    let bytes6 = web3.eth.abi.encodeParameters(["uint256"],[parseInt(nonce.toString())]);

    let str = to + bytes5.substr(2) + (bannerNFT.address).substr(2) + bytes6.substr(2);
    let data = web3.utils.keccak256(str);
    let hash = await web3.eth.sign(data, verifier);

    // console.log("to:", to);
    // console.log("tokenId:", tokenId);
    // console.log("nonce:", nonce.toString());
    // console.log("bannerNFT.address:", bannerNFT.address);
    // console.log("verifier:", verifier);

    let r = hash.substr(0,66);
    let s = "0x" + hash.substr(66,64);
    let v = parseInt(hash.substr(130), 16);
    if (v < 27) {
        v += 27;
    }

    return [v, r, s];
  }

  it("1. should set owner correctly", async () => {
    const owner = await bannerNFT.owner();
    assert.equal(owner, accounts[0], "Owner is not set correctly");
  });

  it("2. should mint a new NFT", async () => {
    const tokenId = 1;    
    const signature = await signNft(accounts[0], tokenId);
    const result = await bannerNFT.safeMint(accounts[0], tokenId, signature[0], signature[1], signature[2], {from: accounts[0]});

    const logs = result.receipt.logs;
    const tokenIdEvent = logs.find(log => log.event === 'Minted');
    const MintedTokenId = tokenIdEvent.args.tokenId;
    // console.log("MintedTokenId:", MintedTokenId.toString());

    const owner = await bannerNFT.ownerOf(MintedTokenId);
    assert.equal(owner, accounts[0], "NFT was not minted successfully");
  });
  

  it("3. should reject minting with incorrect signature", async () => {
    const tokenId = 2;
    const incorrectSignature = [28, "0x42f9a5c5105d6535537ec35dc77cb02bb80b9a6ba0078307c0b7975588888888", "0x5f35a97c02d88aa80f128a8f5d4c53c866ba14168b5d7120822efedebd734701"];
    try {
      const result = await bannerNFT.safeMint(accounts[0], tokenId, incorrectSignature[0], incorrectSignature[1], incorrectSignature[2], {from: accounts[0]});
      assert.fail("Minting with incorrect signature should be rejected");
    } catch (error) {
      assert(error.message.includes("Verification failed about mint banner nft."), "Transaction should revert with incorrect signature");
    }
  });
  
  it("4. should reject minting two NFTs with the same token ID", async () => {
     const tokenId = 1;

    // First mint success
    const signature1 = await signNft(accounts[0], tokenId);
    await bannerNFT.safeMint(accounts[0], tokenId, signature1[0], signature1[1], signature1[2], { from: accounts[0] });

    // The second mint should fail
    try {
      const signature2 = await signNft(accounts[0], tokenId);
      await bannerNFT.safeMint(accounts[0], tokenId, signature2[0], signature2[1], signature2[2], { from: accounts[0] });
      assert.fail("Minting two NFTs with the same token ID should be rejected");
    } catch (error) {
      assert(error.message.includes("revert"), "Transaction should revert when minting two NFTs with the same token ID");
    }
  });

  it("5. should set a new verifier", async () => {
      await bannerNFT.setVerifier(accounts[2], { from: accounts[0] });
      const currentVerifier = await bannerNFT.verifier();
      assert.equal(currentVerifier, accounts[2], "Verifier was not set successfully");
    });

  it("6. should not add a zero address as verifier", async () => {
    try {
      await bannerNFT.setVerifier("0x0000000000000000000000000000000000000000", { from: accounts[0] });
      assert.fail("Zero address should not be allowed as verifier");
    } catch (error) {
      assert(error.message.includes("verifier can't be zero address"), "Error message does not contain correct error message");
    }
  });

  it("7. should update base URI", async () => {
    const tokenId = 1;    
    const signature = await signNft(accounts[0], tokenId);
    await bannerNFT.safeMint(accounts[0], tokenId, signature[0], signature[1], signature[2], {from: accounts[0]});

    const newBaseURI = "https://example.com";
    await bannerNFT.setBaseURI(newBaseURI, { from: accounts[0] });

    const baseURI = await bannerNFT.tokenURI(tokenId)
    const expectedURI = newBaseURI + tokenId;
    assert.equal(baseURI, expectedURI, "Base URI was not updated successfully");
  });

  it("8. should set initial owner correctly during deployment", async () => {
    const initialOwner = await bannerNFT.owner();
    assert.equal(initialOwner, accounts[0], "Initial owner is not set correctly");
  });

  it("9. should restrict setting base URI to owner only", async () => {
    const newBaseURI = "newBaseURI";
    try {
      await bannerNFT.setBaseURI(newBaseURI, { from: accounts[1] });
      assert.fail("Setting base URI by non-owner should be restricted");
    } catch (error) {
      assert(error.message.includes("revert"), "Transaction should revert with non-owner");
    }
  });

});
