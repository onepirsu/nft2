/**
*ERC-1155: Multi Token Standard
*https://eips.ethereum.org/EIPS/eip-1155
*https://docs.openzeppelin.com/contracts/3.x/api/token/erc1155
*https://chaldene.net/erc1155
*/
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Market is ERC1155 ,Ownable{

    constructor() public ERC1155("") {

    }

    //NTFを購入
    function buyToken(address _to,uint256 _id,uint _cost ,uint256 _amount) public payable{
        address owner = owner();
        _safeTransferFrom(owner,_to,_id,_amount,"");
    }

}