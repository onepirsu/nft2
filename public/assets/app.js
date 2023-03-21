

const address = "0x5FbDB2315678afecb367f032d93F642f64180aa3"; // コントラクトアドレス

const web3 = new Web3(Web3.givenProvider || "ws://127.0.0.1:8545");//チェーンネットのアドレス
//const web3 = new Web3(Web3.givenProvider || "http://127.0.0.1:8545")

let inst = new web3.eth.Contract(abi,address);//コントラクトのインスタンス生成
let user;

/**
*「method」：インスタンスのメソッドを使う 
* 「get()」：インスタンス内のget()メソッドを指定
* 「call()」：インスタンスのviewを呼び出している
*/
//「method」インスタンスのメソッドを使う

document.addEventListener('click', async function(event){

    //getをクリックされたら、チェーン上の情報を取得
    if (event.target && event.target.id == "get") {

        const get = await inst.methods.getNFTList().call();

        console.log(get);
        //console.log(get[0].cost);
        //console.log(get[0].issued);
        //console.log(get[0].id);
        if(get){
            var form_elem = document.getElementById("form");

            //指定要素の中の子要素を削除
            while(form_elem.lastChild){
            form_elem.removeChild(form_elem.lastChild);
            }

            //要素を追加
            for(let i = 0;i < get.length;i++){
                var uri = await inst.methods.uri(get[i].id).call();
                var balance = await inst.methods.balanceOfOwner(get[i].id).call();
                console.log(uri);
                // スマートコントラクトのtokenURI()から取得したメタデータのURLを読み込み
                fetch(uri, {method: 'GET', cache: 'no-cache'})
                .then((response) => {
                    return response.json();
                })
                .then((result) => {
                    
                    //displayNFT(result);
                    var cost = get[i].cost / 10 ** 18;
                    form_elem.insertAdjacentHTML('beforeend','<p>tokenId：'+get[i].id+'</p><p>残数：'+balance+'/総発行枚数：'+get[i].issued+'</p><p>購入費用/枚：'+cost+'ETH</p>'+ '<img src="' + result.image + '" style="width:200px;">');
                    form_elem.insertAdjacentHTML('beforeend','<input type="number" name="quantity['+get[i].id+']" value="">個');
                    form_elem.insertAdjacentHTML('beforeend','<div id="balanceof_'+get[i].id+'"></div>');
                    form_elem.insertAdjacentHTML('beforeend','<button type="button" class="purchase" data-tokenid="'+get[i].id+'"data-cost="'+cost+'">購入する</button>');
                });
            }

        }
        
    }

    //pushをクリックされたら、チェーン上に情報を登録
    if (event.target && event.target.id == "mint") {    

        var quantity = document.getElementById("quantity");
        var tokenCost = document.getElementById("tokenCost").value;
        tokenCost = web3.utils.toWei(tokenCost.toString(), "ether");

        try {
            const mintTxt = await inst.methods.mint(quantity.value,tokenCost).send();
            console.log(mintTxt);
            var eventValues = mintTxt.events.Mint.returnValues;
            var cost = parseFloat(web3.utils.fromWei(eventValues._cost, "ether"));
            alert(`
            Mint successful!\n
            Token ID: ${eventValues._id} \n
            Quantity: ${eventValues._quantity}\n
            Cost: ${cost.toFixed(7)} ETH
          `);
        } catch (err) {
            throw err;//reject とほぼ同じ
            console.log(err);
        }
    
    }

    //metadataをクリックされたら、metadata URIを変更
    if (event.target && event.target.id == "metadata") {  
      var uri = document.getElementById("uri").value;

      try {
        await inst.methods.setURI(uri).send();
      } catch (err) {
          throw err;//reject とほぼ同じ
          console.log(err);
      }

    }

    //getBalanceをクリックされたら、残高を表示
    if (event.target && event.target.id == "getBalance") {  

      try {
        var balance = await inst.methods.getBalance().call();
        if(balance < 0){
          balance = 0;
        }else{
          balance = balance / 10 ** 18;
        }

        var balance_elem = document.getElementById("balance");
        while(balance_elem.lastChild){
          balance_elem.removeChild(balance_elem.lastChild);
        }
        balance_elem.insertAdjacentHTML('beforeend','<p>残高：'+balance+'ETH</p>');

      } catch (err) {
          throw err;//reject とほぼ同じ
          console.log(err);
      }

    }

      //withdrawをクリックされたら、残高を引き落とす
      if (event.target && event.target.id == "withdraw") {  

        try {

          await inst.methods.withdraw().send({ from: user });
  
        } catch (err) {
            throw err;//reject とほぼ同じ
            console.log(err);
        }
  
      }

    //pushをクリックされたら、チェーン上に情報を登録
    if (event.target && event.target.id == "connect") {

        try {
            //MetaMaskに接続して上手く言った場合、アカウントを取得出来る
            const accounts = await window.ethereum.request({
            method: "eth_requestAccounts",
            });
            user = accounts[0];//アカウントの「0」には、アドレスが入っている
            inst = new web3.eth.Contract(abi, address, { from: user });//指定のコントラクトのインスタンスを取得

            event.target.style.display = "none";
            var user_elem = document.getElementById("username");
            user_elem.insertAdjacentHTML('beforeend','<p>'+user+'</p>');

            var main_elem = document.getElementById("main");
            main_elem.style.display = 'block';

            //所持数表示
            //指定要素の中の子要素を削除
            var possession_elem = document.getElementById("possession");
            while(possession_elem.lastChild){
              possession_elem.removeChild(possession_elem.lastChild);
            }
            var results = await inst.methods.getOwnNFTList(user).call();
            console.log(results);
            if(results[0]){
              for(let i = 0;i < results[0].length;i++){
                var uri = await inst.methods.uri(results[0][i]).call();
                console.log(uri);
                console.log(results[1][i]);
                if(results[1][i] == 0) continue;
                fetch(uri, {method: 'GET', cache: 'no-cache'})
                .then((response) => {
                    return response.json();
                })
                .then((result) => {
                    possession_elem.insertAdjacentHTML('beforeend','<p>tokenId：'+results[0][i]+'</p><p>所持数：'+results[1][i]+'</p>'+ '<img src="' + result.image + '" style="width:200px;">');
                });

              }
            }

        } catch (error) {
            alert(error.message);
        }

    }

    //purchaseをクリックされたら、NFTを購入
    if (event.target && event.target.className.indexOf('purchase') !== -1) {

        var form = document.getElementById("form");
        var form_data = get_form_data(form);
        console.log(form_data);
        var tokenId = event.target.dataset.tokenid;
        var tokenCost = event.target.dataset.cost;
        var quantity = form_data.get('quantity['+tokenId+']');
        var cost = tokenCost * quantity;
        cost = web3.utils.toWei(cost.toString(), "ether");//etherからweiに変換している。文字列で値を渡す。

        try {
            const buyTokenTxt = await inst.methods.buyToken(user,tokenId,cost,quantity).send({value:cost});
            var eventValues = buyTokenTxt.events.BuyToken.returnValues;
            var cost = parseFloat(web3.utils.fromWei(eventValues._cost, "ether"));
            alert(`
            Purchase successful!\n
            Token ID: ${eventValues._id} \n
            Quantity: ${eventValues._quantity}\n
            Cost: ${cost.toFixed(7)} ETH
          `);
        } catch (err) {
            throw err;//reject とほぼ同じ
            console.log(err);
        }

    }

});


//フォーム内の値を取得してformDataオブジェクトで返す
//---------------------------------------------
function get_form_data(form_elem){

    const post_data = new FormData; // フォーム方式で送る場合
    
    for(elem in form_elem) {
    
      // name未設定のものからは取得しない
      if(form_elem[elem]?.name === undefined || form_elem[elem].name == ""){
        continue;
      }
    
      // チェックボックス、ラジオボタンはチェックが入ってないものは取得しない
      if(form_elem[elem].type == 'checkbox' || form_elem[elem].type == 'radio'){
          if(!form_elem[elem].checked){
              continue;
          }
      }  
    
      // valueが無いものは取得しない
      if(form_elem[elem]?.value === undefined){
        continue;
      }
    
      var name = form_elem[elem].name;
    
      //nameの中に「[」or「]」が含まれる場合 variableの処理
      if ( name.indexOf('[') != -1 || name.indexOf(']') != -1) {
    
        //『[]』で囲まれた値を取得
        var regexp = /\[.+?\]/g;
        const myArray = name.match(regexp);
    
        var cnt = 0;
    
        //keyを格納しておく配列
        var key_array = {};
        for (const elem of myArray) {
    
          cnt++;
    
          //『[]』以降の値を削除
          var name  = name.replace(elem, '');
    
          //抜き出した文字から『[]』を削除 : 純粋な「key」を取得
          var key_value = elem.replace(/\[/g, '').replace(/\]/g, '');
    
          key_array[cnt] = key_value;
    
        }
    
        //console.log(key_array);
    
        if(cnt >= 1) var key1 = key_array[1];
        if(cnt >= 2) var key2 = key_array[2];
        if(cnt >= 3) var key3 = key_array[3];
    
        if(form_elem[elem].type == 'file'){
          var set_value = form_elem[elem].files[0];
        }else{
          var set_value = form_elem[elem].value;
        }
    
        if(cnt == 1){
          post_data.append(name+'['+key1+']', set_value);
        }
        else if(cnt == 2){
          post_data.append(name+'['+key1+']'+'['+key2+']', set_value);
        }
        else if(cnt == 3){
          post_data.append(name+'['+key1+']'+'['+key2+']'+'['+key3+']', set_value);
        }
    
        //console.log(data);
    
      }
      //アップロードファイルの場合file
      else if(form_elem[elem].type == 'file'){
        // valueが無いものは取得しない
        if(form_elem[elem]?.files[0] === undefined){
          continue;
        }
        post_data.append(name, form_elem[elem].files[0]);
      }  
      else{
        post_data.append(name, form_elem[elem].value);
      }
      
    }
    
    return post_data;
    
}
