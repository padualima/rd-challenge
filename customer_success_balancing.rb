require 'minitest/autorun'
require 'timeout'

CustomerSuccessException = Struct.new(:input, :message)
CustomersException = Struct.new(:input, :message)

class CustomerSuccessBalancing
  include Comparable

  def initialize(customer_success, customers, away_customer_success)
    @customer_success = customer_success
    @customers = customers
    @away_customer_success = away_customer_success
  end

  # Returns the ID of the customer success with most customers
  def execute
    return customer_success_exception(:quantity) unless @customer_success.count.between?(1, 999)
    unless @customer_success.count.between?(1, 999)
      return CustomerSuccessNumberException.new("quantity not allowed")
    end
    return customers_exception(:quantity) unless @customers.count.between?(1, 999_999)

    define_available_customer_successes

    sort_by_score(@customer_success)

    balancing_clients_to_customer_successes

    result = customer_success_with_greater_service

    result.one? ? result[0][:id] : 0
  end

  private

  def define_available_customer_successes
    if @away_customer_success.any?
      @customer_success.reject! { |c| @away_customer_success.include?(c[:id]) }
    end
  end

  def sort_by_score(objects=[])
    objects.sort_by! { |obj| obj[:score] }
  end

  def balancing_clients_to_customer_successes
    @customer_success.each do |cs|
      cs[:meet_to_customers] = @customers.select { |c| c[:score] <= cs[:score] }
      @customers = @customers - cs[:meet_to_customers] if cs[:meet_to_customers].any?
    end
  end

  def customer_success_with_greater_service
    group_by_amount_of_customer_meet[1]
  end

  def group_by_amount_of_customer_meet
    @customer_success.group_by { |cs| cs[:meet_to_customers].count }.sort.last
  end

  def generate_exception(klass, input, message)
    klass.new(input, message)
  end

  def customer_success_exception(input, message="amount not allowed")
    generate_exception(CustomerSuccessException, input, message)
  end

  def customers_exception(input, message="amount not allowed")
    generate_exception(CustomersException, input, message)
  end
end

class CustomerSuccessBalancingTests < Minitest::Test
  def test_scenario_one
    balancer = CustomerSuccessBalancing.new(
      build_scores([60, 20, 95, 75]),
      build_scores([90, 20, 70, 40, 60, 10]),
      [2, 4]
    )
    assert_equal 1, balancer.execute
  end

  def test_scenario_two
    balancer = CustomerSuccessBalancing.new(
      build_scores([11, 21, 31, 3, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )
    assert_equal 0, balancer.execute
  end

  def test_scenario_three
    balancer = CustomerSuccessBalancing.new(
      build_scores(Array(1..999)),
      build_scores(Array.new(10000, 998)),
      [999]
    )
    result = Timeout.timeout(1.0) { balancer.execute }
    assert_equal 998, result
  end

  def test_scenario_four
    balancer = CustomerSuccessBalancing.new(
      build_scores([1, 2, 3, 4, 5, 6]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )
    assert_equal 0, balancer.execute
  end

  def test_scenario_five
    balancer = CustomerSuccessBalancing.new(
      build_scores([100, 2, 3, 6, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )
    assert_equal 1, balancer.execute
  end

  def test_scenario_six
    balancer = CustomerSuccessBalancing.new(
      build_scores([100, 99, 88, 3, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      [1, 3, 2]
    )
    assert_equal 0, balancer.execute
  end

  def test_scenario_seven
    balancer = CustomerSuccessBalancing.new(
      build_scores([100, 99, 88, 3, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      [4, 5, 6]
    )
    assert_equal 3, balancer.execute
  end

  def test_scenario_eight
    balancer = CustomerSuccessBalancing.new(
      build_scores(Array(1..1000)),
      build_scores(Array.new(10000, 998)),
      []
    )

    result = balancer.execute

    assert_equal CustomerSuccessException, result.class
    assert_equal :quantity, result.input
    assert_equal "amount not allowed", result.message
  end

  def test_scenario_nine
    balancer = CustomerSuccessBalancing.new(
      [],
      build_scores(Array.new(10000, 998)),
      []
    )

    result = balancer.execute

    assert_equal CustomerSuccessException, result.class
    assert_equal :quantity, result.input
    assert_equal "amount not allowed", result.message
  end

  def test_scenario_ten
    balancer = CustomerSuccessBalancing.new(
      build_scores([11, 21, 31, 3, 4, 5]),
      build_scores(Array.new(1_000_000, 998)),
      []
    )

    result = balancer.execute

    assert_equal CustomersException, result.class
    assert_equal :quantity, result.input
    assert_equal "amount not allowed", result.message
  end

  def test_scenario_eleven
    balancer = CustomerSuccessBalancing.new(
      build_scores([11, 21, 31, 3, 4, 5]),
      [],
      []
    )

    result = balancer.execute

    assert_equal CustomersException, result.class
    assert_equal :quantity, result.input
    assert_equal "amount not allowed", result.message
  end
    assert_equal CustomersNumberException, result.class
    assert_equal "quantity not allowed", result.message
  end

  private

  def build_scores(scores)
    scores.map.with_index do |score, index|
      { id: index + 1, score: score }
    end
  end
end
