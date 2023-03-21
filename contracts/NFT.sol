/**
*ERC-1155: Multi Token Standard
*
*/
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract NFT is ERC1155 ,Ownable{

    /**----------------------------------------------
    * initial setting（変数の定義など）
    ------------------------------------------------*/   
    //発行するNFTのトークンIDの設定
    uint256 constant FIRST_NFT = 0;//constant:定数
    uint256 constant FIRST_NFT_ISSUED = 5;//constant:定数
    
    int256 balance;//NFTコントラクトが所持する残高 (0書き込みだとガス代が掛かる為、符号付きにしてある)

    //NFTの構造体定義
    struct NFTStr{
        uint256 id;
        uint256 issued;//発行数
        uint256 cost;
    }

    mapping(uint256=>bool) exist;//「tokenId => 真偽値」NFTが存在しているかのマッピング
    NFTStr[] NFTData;//NFTを保存しておく変数

    //NFT用MetaDataの格納場所
    string baseMetadataURIPrefix = "http://127.0.0.1:8080/public/metadata/";
    string baseMetadataURISuffix = "";

    //デプロイ時に発行するNFTの設定
    constructor() public ERC1155("") {
        _mint(msg.sender, FIRST_NFT, FIRST_NFT_ISSUED, "");//所有者,トークンID,発行数,bytes data
        exist[FIRST_NFT] = true;//tokenId 0 のNFTをtrueにする
        NFTStr memory newNFT = NFTStr(FIRST_NFT,FIRST_NFT_ISSUED,10**17);
        NFTData.push(newNFT);
    }

    /**----------------------------------------------
    * eventの定義
    ------------------------------------------------*/   
    event Mint(uint256 _id, uint256 _quantity, uint256 _cost);
    event BuyToken(uint256 _id, uint256 _quantity, uint256 _cost);
    event Burn(uint256 _id, uint256 _quantity);
    event SetURI(string _uri);

    /**----------------------------------------------
    * 関数修飾子の定義
    ------------------------------------------------*/   
    //NFTの存在チェック
    modifier existCheck(uint256 _id){
        require(exist[_id] == true ,"The NFT does not exist.");
        _;
    }

    /**----------------------------------------------
    * コントラクト関数の定義
    ------------------------------------------------*/ 
     //NFTの情報を取得する
    function getNFTList() external view returns(NFTStr [] memory){
        return NFTData;
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
    function getOwnNFTList(address _owner) external view returns(uint256 [] memory , uint256 [] memory){
        NFTStr[] memory _NFTData = NFTData;
        uint256 _length = _NFTData.length;
        uint256 _balance;
        uint256 _id;
        uint256[] memory _balances = new uint256[](_length); 
        uint256[] memory _ids = new uint256[](_length);

        for (uint256 i = 0; i < _length; i++){
            _id = _NFTData[i].id;
            _balance = balanceOf(_owner,_id);
            if(_balance > 0){
                _balances[i] = _balance;
                _ids[i] = _id;
            }
        }

        return (_ids,_balances);

    }

    //MetaDataのURIを変更
    function setURI(string memory _uri) external onlyOwner{
        require(keccak256(abi.encodePacked(_uri)) != keccak256(abi.encodePacked("")),unicode"URIが入力されていません。");//unicodeを指定する事で、日本語を設定出来る。
        baseMetadataURIPrefix = _uri;
        emit SetURI(_uri);
    }

    //NFTの発行者がいくつ所有しているか？＝NFTの残数がいくつか？
    function balanceOfOwner(uint256 _id) external view existCheck(_id) returns(uint256){
        address _owner = owner();
        uint256 _balance = balanceOf(_owner,_id);
        return _balance;
    }

    //NTFコントラクトが所持している残高
    function getBalance() external view onlyOwner returns(int256){
        return balance;
    }

    //NTFコントラクトが所持している残高から引き出す
    function withdraw() external onlyOwner{
        require(balance > 0,unicode"残高がありません。");
        uint256 _amount = uint256(balance);
        balance = -1;//gas代節約の為、0にならない様にしている
        payable(msg.sender).transfer(_amount);//msg.sender アドレスに、任意の_amountを送金する
    }
    
    //NTFを購入
    function buyToken(address _to,uint256 _id,uint256 _cost ,uint256 _quantity) external payable existCheck(_id){
        address _owner = owner();
        uint256 _balance = balanceOf(_owner,_id);
        require(_owner != _to ,unicode"受け取りアドレスが不正です。");//unicodeを指定する事で、日本語を設定出来る。
        require(_balance >= _quantity ,unicode"残数以上の数量が入力されています。");//unicodeを指定する事で、日本語を設定出来る。
        _safeTransferFrom(_owner,_to,_id,_quantity,"");
        balance += int256(msg.value);
        emit BuyToken(_id, _quantity, _cost);
    }
    
    /**
    * 新たなNTFを発行
    * _value：発行数量,_cost：購入コスト
     */
    function mint(uint256 _quantity,uint256 _cost) external onlyOwner{
        require(_quantity != 0 ,"quantity required.");
        require(_cost != 0 ,"cost required.");
        uint256 _id = NFTData.length;
        _mint(msg.sender, _id, _quantity, "");
        NFTStr memory newNFT = NFTStr(_id,_quantity,_cost);
        NFTData.push(newNFT);
        exist[_id] = true;
        emit Mint(_id, _quantity, _cost);
    }

    //NTFを燃やす
    function burn(address _to,uint256 _id,uint256 _quantity) external{
        require(msg.sender == _to,unicode"削除する権限はありません。");

        uint256 _balance = balanceOf(_to,_id);
        require(_balance >= _quantity,unicode"数量が所持数を超えています。");

        //指定のアドレスが所有している指定のIDのNTFを指定の数量燃やす関数
        _burn(_to, _id, _quantity);
        emit Burn(_id, _quantity);
    }

}