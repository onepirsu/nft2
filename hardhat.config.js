require("@nomicfoundation/hardhat-toolbox");
//require("@nomiclabs/hardhat-waffle");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.19",
};
/*
//mumbai
module.exports = {
  solidity: "0.8.19",
  networks: {
    polygon_mumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/${process.env.SNM_MUMBAI_API_KEY}`,
      accounts: [`0x${process.env.DAPP_DEVELOPMENT_WALLET_PRIVATE_KEY}`]
    }
  }
};
*/
/*
//polygon mainnet
module.exports = {
  solidity: "0.8.19",
  networks: {
		polygon: {
      url: `https://polygon-mainnet.g.alchemy.com/v2/${process.env.SNM_POLYGON_MAINNET_API_KEY}`,
      accounts: [`0x${process.env.DAPP_DEVELOPMENT_WALLET_PRIVATE_KEY}`],
      gasPrice: 9000000000000000000,  
    }
  }
};
*/