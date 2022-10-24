const { ethers } = require("ethers");

// contract information
const SIGNING_DOMAIN_NAME = "tbc"
const SIGNING_DOMAIN_VERSION = "1"
const chainId = 1
const contractAddress = "0x7EF2e0048f5bAeDe046f6BF797943daF4ED8CB47" // Put the address of contract
const minterPrivateKey = "503f38a9c967ed597e47fe25643985f032b072db8075426a92110f82df48dfcb"
const signer = new ethers.Wallet(minterPrivateKey) // private key that is authorised to sign

 // voucer information 
const seller = "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4";
const buyer = "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2";
const currency = "X";
const price = 0;
const uid = (Date.now() + Math.random()).toString();

console.log(uid);

const domain = {
  name: SIGNING_DOMAIN_NAME,
  version: SIGNING_DOMAIN_VERSION,
  verifyingContract: contractAddress,
  chainId
}

async function createVoucher(seller, buyer, currency, price, uid) {
  const voucher = { seller, buyer, currency, price, uid }
  const types = {
    LazyMintExternalNftData: [
      {name: "seller", type: "address"},
      {name: "buyer", type: "address"},
      {name: "currency", type: "string"},
      {name: "price", type: "uint256"},
      {name: "uid", type: "string"}
    ]
  }

  const signature = await signer._signTypedData(domain, types, voucher)
  return {
    ...voucher,
    signature
  }
}

async function main() {
  const voucher = await createVoucher(seller,buyer,currency,price,uid) ;
  console.log(`["${voucher.seller}", "${voucher.buyer}", "${voucher.currency}", "${voucher.price}", "${voucher.uid}", "${voucher.signature}"]`)
}
main();