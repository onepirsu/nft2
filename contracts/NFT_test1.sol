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

contract NFT is ERC1155 ,Ownable{

    
    //発行するNFTのトークンIDの設定
    /**
    * constant:定数
    */
    uint256 public constant FIRST_NFT = 0;

    //NFTの構造体
    struct NFTStr{
        uint256 id;
        uint256 issued;//発行数
        uint256 cost;
    }

    mapping(uint256=>bool) NFTEnable;//「tokenId => 真偽値」NFTが存在しているかのマッピング
    mapping(uint256=>uint256) IdToNFTData;//「tokenId => 配列No」NFTの配列番号とNFTのtokenIDを紐づけるマッピング
    NFTStr[] NFTData;

    string baseMetadataURIPrefix = "http://127.0.0.1:8080/public/metadata/";
    string baseMetadataURISuffix = "";

    //発行できるNFTの数量設定
    /**
    * constructor：deploy時に実行される特別な関数
     */
    constructor() public ERC1155("") {
        _mint(msg.sender, FIRST_NFT, 1, "");//所有者,トークンID,発行数,bytes data

        NFTEnable[FIRST_NFT] = true;
        IdToNFTData[FIRST_NFT] = 0;

        NFTStr memory newNFT = NFTStr(FIRST_NFT,1,10**17);
        NFTData.push(newNFT);

    }

    /**
    *関数修飾子の定義
    */
    modifier NFTCheck(uint256 _id){
        require(NFTEnable[_id] == true ,"That NFT does not exist.");
        _;
    }

    /**
    *コントラクト関数の定義
    */
     //指定したトークンIDの情報を取得する
    function getNFTList() public view returns(NFTStr [] memory){
        return NFTData;
    }

    //指定したトークンIDの情報を取得する
    function getNFTnInfo(uint256 _id) public view NFTCheck(_id) returns(NFTStr memory){
        uint arrayId = IdToNFTData[_id];
        return NFTData[arrayId];
    }

    //OpenSeaなどが、NFTのメタデータを取得する関数
    function uri(uint256 _id) public view override returns (string memory) {
        // "https://~~~" + tokenID + ".json" の文字列結合を行っている
        return string(abi.encodePacked(
            baseMetadataURIPrefix,
            Strings.toString(_id),
            baseMetadataURISuffix
        ));
    }

    //任意のアドレスが所持しているNFTの情報を取得
    function getOwnNFTList(address _owner) public view returns(uint256 [] memory , uint256 [] memory){
        NFTStr[] memory _NFTData = NFTData;
        uint256 _length = _NFTData.length;
        uint256 _balance;
        uint256 _id;
        uint256[] memory _balances = new uint256[](_length); 
        uint256[] memory _ids = new uint256[](_length);

        for (uint256 i = 0; i < _length; i++){
            _id = _NFTData[i].id;
            _balance = uint256(balanceOf(_owner,_id));
            if(_balance > 0){
                _balances[i] = _balance;
                _ids[i] = _id;
            }
        }

        return (_ids,_balances);

    }

    //NTFを購入
    function buyToken(address _to,uint256 _id,uint _cost ,uint256 _amount) public payable{
        address owner = owner();
        _safeTransferFrom(owner,_to,_id,_amount,"");
    }

    //新たなNTFを発行
    //id（配列）と数量（配列）を引数で渡す
    function mint(uint256 _id,uint256 _value,uint256 _cost) public onlyOwner{
        require(_id != 0 ,"0 cannot be entered.");
        require(_value != 0 ,"value required.");
        require(NFTEnable[_id] == false ,"That NFT does already exist.");
        address owner = owner();
        _mint(owner, _id, _value, "");
        NFTStr memory newNFT = NFTStr(_id,_value,_cost);
        uint256 arrayNo = NFTData.length;
        NFTData.push(newNFT);
        NFTEnable[_id] = true;
        IdToNFTData[_id] = arrayNo;
    }

}