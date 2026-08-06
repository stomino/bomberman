from matchmaking.queue_manager import QueueManager


def test_pop_pair_returns_none_with_fewer_than_two():
    q = QueueManager()
    assert q.pop_pair() is None
    q.add("a")
    assert q.pop_pair() is None


def test_pop_pair_returns_fifo_order():
    q = QueueManager()
    q.add("a")
    q.add("b")
    q.add("c")
    assert q.pop_pair() == ("a", "b")
    assert q.waiting_count() == 1


def test_pop_pair_removes_matched_clients_from_queue():
    q = QueueManager()
    q.add("a")
    q.add("b")
    q.pop_pair()
    assert q.waiting_count() == 0
    assert q.pop_pair() is None


def test_remove_takes_client_out_of_queue():
    q = QueueManager()
    q.add("a")
    q.add("b")
    q.remove("a")
    assert q.waiting_count() == 1
    assert q.pop_pair() is None  # solo queda "b"


def test_remove_is_safe_for_client_not_in_queue():
    q = QueueManager()
    q.remove("ghost")  # no debería lanzar


def test_add_does_not_duplicate_same_client():
    q = QueueManager()
    q.add("a")
    q.add("a")
    assert q.waiting_count() == 1
